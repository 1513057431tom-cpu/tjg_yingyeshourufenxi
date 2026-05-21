DROP PROCEDURE IF EXISTS public.Cost_Data_Cost_Sales_Nospecialty_Drugs_JYYC_levels3(varchar, int4, text);
CREATE OR REPLACE PROCEDURE public.Cost_Data_Cost_Sales_Nospecialty_Drugs_JYYC_levels3(
    IN s_cperiod varchar, 
    INOUT result int4, 
    INOUT msg text
)
AS $BODY$
DECLARE
-- 基础变量

    s_cperiod_year        VARCHAR(30);
    s_cperiod_year_month  VARCHAR(30);
    s_cperiod_start_month VARCHAR(30);


    -- 两票制费用总额
    s_js_lpz_fyamount NUMERIC(24,8);
    s_zs_lpz_fyamount NUMERIC(24,8);

    -- 临时变量（用于接收调用子过程的返回值）
    v_sub_result INT4;
    v_sub_msg    TEXT;
BEGIN
    -- 初始化返回值
    result := 1;
    msg := '票折计算，处理成功';
	RAISE NOTICE '票折计算，开始处理: ';
	-- 拆分年月
    s_cperiod_year       := SPLIT_PART(s_cperiod, '-', 1);
    s_cperiod_year_month := SPLIT_PART(s_cperiod, '-', 2);
    s_cperiod_start_month := CONCAT(s_cperiod_year, '-01');  
	  
    
    -- 清理所有中间表（调试时每次重新执行前运行）
    DROP TABLE IF EXISTS tmp_invoice_base;
    DROP TABLE IF EXISTS tmp_dim_aggregates;
    DROP TABLE IF EXISTS tmp_fdq_detail;
    DROP TABLE IF EXISTS tmp_fdq_levels;
    DROP TABLE IF EXISTS tmp_invoice_materials;
    DROP TABLE IF EXISTS tmp_fdq_material_match;
    DROP TABLE IF EXISTS tmp_fdq_reallocated;
    DROP TABLE IF EXISTS tmp_fdq_by_target_normal;
    DROP TABLE IF EXISTS tmp_normal_denom_5d;
    DROP TABLE IF EXISTS tmp_normal_denom_3d;
    DROP TABLE IF EXISTS tmp_fdq_by_target_fallback;
    DROP TABLE IF EXISTS tmp_material_sales_total;
    DROP TABLE IF EXISTS tmp_fallback_denom_4d;
    DROP TABLE IF EXISTS tmp_fallback_denom_2d;
    DROP TABLE IF EXISTS tmp_conversion_allocation_normal;
    DROP TABLE IF EXISTS tmp_conversion_allocation_fallback;
    DROP TABLE IF EXISTS tmp_conversion_amount;
    DROP TABLE IF EXISTS tmp_final_calc;
    DROP TABLE IF EXISTS tmp_final_calc_extended;
  
  -- ========================================
  -- 表1：tmp_invoice_base（发票明细基础信息）
  -- 依赖：无
  -- ========================================
  CREATE TABLE tmp_invoice_base AS
  SELECT
      ibslt.id,
      ibslt.srcid,
      ibslt.csaleinvoiceid,
      ibslt.cinvoicecustid,
      ibslt.material_code,
      ibslt.cmaterialvid,
      ibslt.nnum,
      ibslt.bhdq_pz_cdq_bhs,
      ibslt.cperiod,
      ptpcr.cdeptvid AS original_cdeptvid,
      ptpcr.sales_channel,
      ptpcr.cemployeeid,
      CASE
          WHEN ptpcr.cdeptvid = '0001E9100000003ZB596' THEN '0001E910000000A9FH0J'
          WHEN ptpcr.cdeptvid = '0001E9100000003ZB594' THEN '0001E910000000A93SN9'
          ELSE ptpcr.cdeptvid
      END AS mapped_cdeptvid
  FROM mis_auto_puyao_jyycmx ibslt
  INNER JOIN mis_auto_ptpcr ptpcr
      ON ptpcr.csaleinvoiceid1 = ibslt.csaleinvoiceid
      AND ibslt.srcid = ptpcr.id
  WHERE ibslt.cperiod = s_cperiod;
 
  
  -- ========================================
  -- 表2：tmp_dim_aggregates（发票多级汇总）
  -- 依赖：tmp_invoice_base
  -- ========================================
  CREATE TABLE tmp_dim_aggregates AS
  SELECT
      cinvoicecustid,
      mapped_cdeptvid,
      sales_channel,
      cemployeeid,
      CASE WHEN s_cperiod_year = '2025' THEN NULL ELSE cmaterialvid END AS material_vid,
      SUM(bhdq_pz_cdq_bhs) AS total_bhdq_amount,
      SUM(nnum) AS total_invoicenum,
      CASE
          WHEN GROUPING(sales_channel) = 0 AND GROUPING(cemployeeid) = 0 THEN 1
          ELSE 2
      END AS level_id
  FROM tmp_invoice_base
  GROUP BY GROUPING SETS (
      (cinvoicecustid, mapped_cdeptvid, sales_channel, cemployeeid,
       CASE WHEN s_cperiod_year = '2025' THEN NULL ELSE cmaterialvid END),
      (cinvoicecustid, mapped_cdeptvid,
       CASE WHEN s_cperiod_year = '2025' THEN NULL ELSE cmaterialvid END)
  );
 
  -- ========================================
  -- 表3：tmp_fdq_detail（非当期票折明细）
  -- 依赖：无（直接查源表）
  -- ========================================
  CREATE TABLE tmp_fdq_detail AS
  SELECT
      sub.cinvoicecustid,
      subb.vbdef1 AS material_vid,
      COALESCE(map.cdepvid, sub.cdeptvid) AS original_cdeptvid,
      CASE
          WHEN sub.cdeptvid = '0001E910000000A93SN9' THEN sub.cdeptvid
          WHEN sub.cdeptvid = '0001E910000000A9FH0J' THEN sub.cdeptvid
          WHEN COALESCE(map.cdepvid, sub.cdeptvid) = '0001E9100000003ZB596' THEN '0001E910000000A9FH0J'
          WHEN COALESCE(map.cdepvid, sub.cdeptvid) = '0001E9100000003ZB594' THEN '0001E910000000A93SN9'
          ELSE COALESCE(map.cdepvid, sub.cdeptvid)
      END AS mapped_cdeptvid,
      sub.cemployeeid,
      sub.sales_channel,
      detail.ndetailsubmny,
      sub.ctrantypeid
  FROM mis_auto_idkur detail
  INNER JOIN mis_auto_ccxbd_sub_carsubbid subb
      ON subb.carsubbid = detail.carsubbid
  INNER JOIN mis_auto_ccxbd sub
      ON sub.carsubid = subb.carsubid
  INNER JOIN (
      SELECT DISTINCT csaleinvoiceid FROM mis_auto_puyao_jyycmx WHERE cperiod = s_cperiod
  ) ibslt ON ibslt.csaleinvoiceid = detail.csalebillid
  LEFT JOIN (
      SELECT DISTINCT ON (dep.pk_vid)
          d.pk_vid   AS cdepvid,
          dep.pk_vid AS pdepvid
      FROM mis_auto_mhrio_sub_duizhaomingxi duizhaomingxi
      INNER JOIN mis_auto_mhrio mhrio
          ON mhrio.id = duizhaomingxi.masid AND mhrio.status = 1 AND mhrio.isvoid = 0
      LEFT JOIN mis_auto_yuorb d   ON d.code = duizhaomingxi.cdeptcode
      LEFT JOIN mis_auto_yuorb dep ON dep.code = duizhaomingxi.pdeptcode
      INNER JOIN mis_auto_ptpcr ptpr
          ON d.pk_vid = ptpr.cdeptvid
          AND ptpr.cperiod >= s_cperiod_start_month
          AND ptpr.cperiod <= s_cperiod
      WHERE mhrio.cperiod = s_cperiod AND duizhaomingxi.isvoid = 0
      GROUP BY d.pk_vid, dep.pk_vid
  ) map ON map.pdepvid = sub.cdeptvid
  WHERE sub.ctrantypeid IN ('1001A11000000000Y15D', '1001E9100000013JGFMH');

 
    
  -- ========================================
  -- 表4：tmp_fdq_levels（票折金额两级汇总）
  -- 依赖：tmp_fdq_detail
  -- ========================================
  CREATE TABLE tmp_fdq_levels AS
  SELECT
      cinvoicecustid,
      mapped_cdeptvid,
      sales_channel,
      cemployeeid,
      CASE WHEN s_cperiod_year = '2025' THEN NULL ELSE material_vid END AS material_vid,
      SUM(CASE WHEN ctrantypeid = '1001A11000000000Y15D' THEN ndetailsubmny ELSE 0 END) AS fdq_amount,
      SUM(CASE WHEN ctrantypeid = '1001E9100000013JGFMH' THEN ndetailsubmny ELSE 0 END) AS fdqb_amount,
      CASE
          WHEN GROUPING(sales_channel) = 0 AND GROUPING(cemployeeid) = 0 THEN 1
          ELSE 2
      END AS level_id
  FROM tmp_fdq_detail
  GROUP BY GROUPING SETS (
      (cinvoicecustid, mapped_cdeptvid, sales_channel, cemployeeid,
       CASE WHEN s_cperiod_year = '2025' THEN NULL ELSE material_vid END),
      (cinvoicecustid, mapped_cdeptvid,
       CASE WHEN s_cperiod_year = '2025' THEN NULL ELSE material_vid END)
  );
 
  
  -- ========================================
  -- 表5：tmp_invoice_materials（发票物料编码集合）
  -- 依赖：tmp_invoice_base
  -- ========================================
  CREATE TABLE tmp_invoice_materials AS
  SELECT DISTINCT material_code, cmaterialvid
  FROM tmp_invoice_base
  WHERE cperiod = s_cperiod;
  
  -- 验证
  -- SELECT COUNT(1) AS material_count FROM tmp_invoice_materials;
  -- ========================================
  -- 表6：tmp_fdq_material_match（物料匹配状态）
  -- 依赖：tmp_fdq_levels, tmp_invoice_materials
  -- ========================================
  CREATE TABLE tmp_fdq_material_match AS
  SELECT
      fl.cinvoicecustid,
      fl.mapped_cdeptvid,
      fl.sales_channel,
      fl.cemployeeid,
      fl.material_vid,
      fl.fdq_amount,
      fl.fdqb_amount,
      fl.level_id,
      CASE WHEN im.cmaterialvid IS NOT NULL THEN 1 ELSE 0 END AS original_exists,
      inv.pk_material AS converted_material_code,
      CASE WHEN im2.cmaterialvid IS NOT NULL THEN 1 ELSE 0 END AS converted_exists
  FROM tmp_fdq_levels fl
  LEFT JOIN tmp_invoice_materials im 
      ON im.cmaterialvid = fl.material_vid
  LEFT JOIN mis_auto_rbyld ON mis_auto_rbyld.pk_material = fl.material_vid
  LEFT JOIN mis_auto_uuelb_sub_zhuanhuanguize conv
      ON conv.material_code = mis_auto_rbyld.code
  LEFT JOIN mis_auto_rbyld inv ON inv.code = conv.cinvcode
  LEFT JOIN tmp_invoice_materials im2
      ON im2.material_code = conv.cinvcode
  WHERE s_cperiod_year != '2025';
 

  -- ========================================
  -- 表7：tmp_fdq_reallocated（重新归类票折金额）
  -- 依赖：tmp_fdq_material_match
  -- ========================================
  CREATE TABLE tmp_fdq_reallocated AS
  SELECT
      cinvoicecustid,
      mapped_cdeptvid,
      sales_channel,
      cemployeeid,
      level_id,
      CASE
          WHEN original_exists = 1 THEN material_vid
          WHEN original_exists = 0 AND converted_exists = 1 THEN converted_material_code
          ELSE 'FALLBACK'
      END AS target_material,
      fdq_amount,
      fdqb_amount
  FROM tmp_fdq_material_match;
 
  
  -- ========================================
  -- 表8：tmp_fdq_by_target_normal（场景1/2 物料级汇总）
  -- 依赖：tmp_fdq_reallocated
  -- ========================================
  CREATE TABLE tmp_fdq_by_target_normal AS
  SELECT
       cinvoicecustid,
      mapped_cdeptvid,
      sales_channel,
      cemployeeid,
      target_material,
      SUM(fdq_amount) AS fdq_amount,
      SUM(fdqb_amount) AS fdqb_amount
  FROM tmp_fdq_reallocated
  WHERE target_material != 'FALLBACK'
    AND level_id = 1
  GROUP BY  cinvoicecustid,
      mapped_cdeptvid,
      sales_channel,
      cemployeeid,target_material;

 
    -- ========================================
    -- 新增：tmp_normal_denom_5d（五维数量分母：客户+部门+渠道+业务员+物料）
    -- ========================================
    CREATE TABLE tmp_normal_denom_5d AS
    SELECT
        cinvoicecustid,
        mapped_cdeptvid,
        sales_channel,
        cemployeeid,
        cmaterialvid,
        SUM(nnum) AS total_num
    FROM tmp_invoice_base
    WHERE cperiod = s_cperiod
    GROUP BY cinvoicecustid, mapped_cdeptvid, sales_channel, cemployeeid, cmaterialvid;

    -- 验证
    -- SELECT COUNT(1) AS cnt, SUM(total_num) AS total FROM tmp_normal_denom_5d;


    -- ========================================
    -- 新增：tmp_normal_denom_3d（三维数量分母：客户+部门+物料）
    -- ========================================
    CREATE TABLE tmp_normal_denom_3d AS
    SELECT
        cinvoicecustid,
        mapped_cdeptvid,
       --  cmaterialvid,
        SUM(nnum) AS total_num
    FROM tmp_invoice_base
    WHERE cperiod = s_cperiod
    GROUP BY cinvoicecustid, mapped_cdeptvid ; -- , cmaterialvid;

    -- 验证
    -- SELECT COUNT(1) AS cnt, SUM(total_num) AS total FROM tmp_normal_denom_3d;
    
  -- ========================================
  -- 表9：tmp_fdq_by_target_fallback（场景3 维度级汇总）
  -- 依赖：tmp_fdq_reallocated
  -- ========================================
  CREATE TABLE tmp_fdq_by_target_fallback AS
  SELECT
      cinvoicecustid,
      mapped_cdeptvid,
      sales_channel,
      cemployeeid,
      target_material,
      level_id,
      SUM(fdq_amount) AS fdq_amount,
      SUM(fdqb_amount) AS fdqb_amount
  FROM tmp_fdq_reallocated
  WHERE target_material = 'FALLBACK'
  GROUP BY cinvoicecustid, mapped_cdeptvid, sales_channel, cemployeeid, target_material, level_id;
 
    -- ========================================
    -- 表10：tmp_material_sales_total（物料销售数量）
    -- 依赖：tmp_invoice_base
    -- ========================================
    CREATE TABLE tmp_material_sales_total AS
    SELECT
        cmaterialvid,
        SUM(nnum) AS total_num
    FROM tmp_invoice_base
    WHERE cperiod = s_cperiod
    GROUP BY cmaterialvid;
 
    -- ========================================
    -- 表11：tmp_fallback_denom_4d（4维度分母）
    -- 依赖：tmp_invoice_base
    -- ========================================
    CREATE TABLE tmp_fallback_denom_4d AS
    SELECT
        cinvoicecustid,
        mapped_cdeptvid,
        sales_channel,
        cemployeeid,
        SUM(bhdq_pz_cdq_bhs) AS total_amount
    FROM tmp_invoice_base
    WHERE cperiod = s_cperiod
    GROUP BY cinvoicecustid, mapped_cdeptvid, sales_channel, cemployeeid;

 
  -- ========================================
  -- 表12：tmp_fallback_denom_2d（2维度分母）
  -- 依赖：tmp_invoice_base
  -- ========================================
  CREATE TABLE tmp_fallback_denom_2d AS
  SELECT
      cinvoicecustid,
      mapped_cdeptvid,
      SUM(bhdq_pz_cdq_bhs) AS total_amount
  FROM tmp_invoice_base
  WHERE cperiod = s_cperiod
  GROUP BY cinvoicecustid, mapped_cdeptvid;
 
  -- ========================================
  -- 表13：tmp_conversion_allocation_normal（场景1/2 分摊明细）
  -- 依赖：tmp_fdq_by_target_normal, tmp_material_sales_total, tmp_invoice_base
  -- ========================================
  CREATE TABLE tmp_conversion_allocation_normal AS
  
    -- 第一部分：五维有发票数据 → 按五维数量占比分摊
    SELECT
        fbt.cinvoicecustid,
        fbt.mapped_cdeptvid,
        fbt.sales_channel,
        fbt.cemployeeid,
        fbt.target_material,
        ib.id AS target_id,
        ib.srcid AS target_srcid,
        ib.nnum AS target_num,
        d5.total_num AS denominator,
        fbt.fdq_amount,
        fbt.fdqb_amount,
        COALESCE(
            ROUND(fbt.fdq_amount * (ib.nnum::NUMERIC / NULLIF(d5.total_num, 0)), 8),
            0
        ) AS alloc_fdq_amount,
        COALESCE(
            ROUND(fbt.fdqb_amount * (ib.nnum::NUMERIC / NULLIF(d5.total_num, 0)), 8),
            0
        ) AS alloc_fdqb_amount
    FROM tmp_fdq_by_target_normal fbt
    INNER JOIN tmp_invoice_base ib
        ON ib.cmaterialvid = fbt.target_material
        AND ib.cinvoicecustid = fbt.cinvoicecustid
        AND ib.mapped_cdeptvid = fbt.mapped_cdeptvid
        AND ib.sales_channel = fbt.sales_channel
        AND ib.cemployeeid = fbt.cemployeeid
    INNER JOIN tmp_normal_denom_5d d5
        ON d5.cinvoicecustid = fbt.cinvoicecustid
        AND d5.mapped_cdeptvid = fbt.mapped_cdeptvid
        AND d5.sales_channel = fbt.sales_channel
        AND d5.cemployeeid = fbt.cemployeeid
        AND d5.cmaterialvid = fbt.target_material
    WHERE d5.total_num <> 0
      AND ib.cperiod = s_cperiod

    UNION ALL

    -- 第二部分：五维无发票数据 → 降级到三维（客户+部门+物料）按数量占比分摊
    -- 注意：ib 不再限定 sales_channel 和 cemployeeid，只要同客户+部门+物料即可
    SELECT
        fbt.cinvoicecustid,
        fbt.mapped_cdeptvid,
        fbt.sales_channel,
        fbt.cemployeeid,
        fbt.target_material,
        ib.id AS target_id,
        ib.srcid AS target_srcid,
        ib.nnum AS target_num,
        d3.total_num AS denominator,
        fbt.fdq_amount,
        fbt.fdqb_amount,
        COALESCE(
            ROUND(fbt.fdq_amount * (ib.nnum::NUMERIC / NULLIF(d3.total_num, 0)), 8),
            0
        ) AS alloc_fdq_amount,
        COALESCE(
            ROUND(fbt.fdqb_amount * (ib.nnum::NUMERIC / NULLIF(d3.total_num, 0)), 8),
            0
        ) AS alloc_fdqb_amount
    FROM tmp_fdq_by_target_normal fbt
    INNER JOIN tmp_invoice_base ib
        ON  ib.cinvoicecustid = fbt.cinvoicecustid
        AND ib.mapped_cdeptvid = fbt.mapped_cdeptvid
        -- AND ib.cmaterialvid = fbt.target_material
    LEFT JOIN tmp_normal_denom_5d d5
        ON d5.cinvoicecustid = fbt.cinvoicecustid
        AND d5.mapped_cdeptvid = fbt.mapped_cdeptvid
        AND d5.sales_channel = fbt.sales_channel
        AND d5.cemployeeid = fbt.cemployeeid
        AND d5.cmaterialvid = fbt.target_material
    INNER JOIN tmp_normal_denom_3d d3
        ON d3.cinvoicecustid = fbt.cinvoicecustid
        AND d3.mapped_cdeptvid = fbt.mapped_cdeptvid
       --  AND d3.cmaterialvid = fbt.target_material
    WHERE (d5.total_num IS NULL OR d5.total_num = 0)   -- 五维无数据才降级
      AND d3.total_num <> 0  AND ib.cperiod = s_cperiod;


 
    -- ========================================
    -- 表14：tmp_conversion_allocation_fallback（场景3 分摊明细）
    -- 依赖：tmp_fdq_by_target_fallback, tmp_invoice_base, tmp_fallback_denom_4d, tmp_fallback_denom_2d
    -- ========================================
    CREATE TABLE tmp_conversion_allocation_fallback AS

    -- 第一部分：level 1 且 4维度有发票数据 → 按4维度分摊
    SELECT
        fbt.cinvoicecustid,
        fbt.mapped_cdeptvid,
        fbt.sales_channel,
        fbt.cemployeeid,
        fbt.target_material,
        fbt.level_id,
        ib.id AS target_id,
        ib.srcid AS target_srcid,
        ib.bhdq_pz_cdq_bhs AS target_amount,
        d4.total_amount AS denominator,
        fbt.fdq_amount,
        fbt.fdqb_amount,
        COALESCE(
            ROUND(fbt.fdq_amount * (ib.bhdq_pz_cdq_bhs::NUMERIC / NULLIF(d4.total_amount, 0)), 8), 
            0
        ) AS alloc_fdq_amount,
        COALESCE(
            ROUND(fbt.fdqb_amount * (ib.bhdq_pz_cdq_bhs::NUMERIC / NULLIF(d4.total_amount, 0)), 8), 
            0
        ) AS alloc_fdqb_amount
    FROM tmp_fdq_by_target_fallback fbt
    INNER JOIN tmp_invoice_base ib
        ON ib.cinvoicecustid = fbt.cinvoicecustid
        AND ib.mapped_cdeptvid = fbt.mapped_cdeptvid
        AND ib.sales_channel = fbt.sales_channel
        AND ib.cemployeeid = fbt.cemployeeid
    INNER JOIN tmp_fallback_denom_4d d4
        ON d4.cinvoicecustid = fbt.cinvoicecustid
        AND d4.mapped_cdeptvid = fbt.mapped_cdeptvid
        AND d4.sales_channel = fbt.sales_channel
        AND d4.cemployeeid = fbt.cemployeeid
    WHERE fbt.level_id = 1
      AND d4.total_amount <> 0
      AND ib.cperiod = s_cperiod

    UNION ALL

    -- 第二部分：level 1 且 4维度无发票数据 → 降级到2维度分摊
    -- 这里的金额自然就是"level 2 减去 4维度已匹配金额"
    SELECT
        fbt.cinvoicecustid,
        fbt.mapped_cdeptvid,
        fbt.sales_channel,
        fbt.cemployeeid,
        fbt.target_material,
        fbt.level_id,
        ib.id AS target_id,
        ib.srcid AS target_srcid,
        ib.bhdq_pz_cdq_bhs AS target_amount,
        d2.total_amount AS denominator,
        fbt.fdq_amount,
        fbt.fdqb_amount,
        COALESCE(
            ROUND(fbt.fdq_amount * (ib.bhdq_pz_cdq_bhs::NUMERIC / NULLIF(d2.total_amount, 0)), 8), 
            0
        ) AS alloc_fdq_amount,
        COALESCE(
            ROUND(fbt.fdqb_amount * (ib.bhdq_pz_cdq_bhs::NUMERIC / NULLIF(d2.total_amount, 0)),8), 
            0
        ) AS alloc_fdqb_amount
    FROM tmp_fdq_by_target_fallback fbt
    INNER JOIN tmp_invoice_base ib
        ON ib.cinvoicecustid = fbt.cinvoicecustid
        AND ib.mapped_cdeptvid = fbt.mapped_cdeptvid
    LEFT JOIN tmp_fallback_denom_4d d4
        ON d4.cinvoicecustid = fbt.cinvoicecustid
        AND d4.mapped_cdeptvid = fbt.mapped_cdeptvid
        AND d4.sales_channel = fbt.sales_channel
        AND d4.cemployeeid = fbt.cemployeeid
    INNER JOIN tmp_fallback_denom_2d d2
        ON d2.cinvoicecustid = fbt.cinvoicecustid
        AND d2.mapped_cdeptvid = fbt.mapped_cdeptvid
    WHERE fbt.level_id = 1
      AND (d4.total_amount IS NULL OR d4.total_amount = 0)  -- 4维度无数据才降级
      AND d2.total_amount <> 0
      AND ib.cperiod = s_cperiod;

 
    -- ========================================
    -- 表15：tmp_conversion_amount（转换分摊金额汇总）
    -- 依赖：tmp_conversion_allocation_normal, tmp_conversion_allocation_fallback
    -- ========================================
    CREATE TABLE tmp_conversion_amount AS
    -- 场景1/2：直接汇总已算好的 alloc_ 金额
    SELECT
        target_id,
        target_srcid,
        SUM(alloc_fdq_amount) AS conv_fdq_amount,
        SUM(alloc_fdqb_amount) AS conv_fdqb_amount
    FROM tmp_conversion_allocation_normal
    GROUP BY target_id, target_srcid

    UNION ALL

    -- 场景3：直接汇总已算好的 alloc_ 金额
    SELECT
        target_id,
        target_srcid,
        SUM(alloc_fdq_amount) AS conv_fdq_amount,
        SUM(alloc_fdqb_amount) AS conv_fdqb_amount
    FROM tmp_conversion_allocation_fallback
    GROUP BY target_id, target_srcid;
 
       

EXCEPTION
    WHEN OTHERS THEN
        result := -1;
        msg := SQLERRM;
        RAISE NOTICE '存储过程异常: %', SQLERRM;
END;
$BODY$
LANGUAGE plpgsql;

