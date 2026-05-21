DROP PROCEDURE IF EXISTS public.Cost_Data_Cost_Sales_Nospecialty_JJRC(varchar, int4, text);
CREATE OR REPLACE PROCEDURE public.Cost_Data_Cost_Sales_Nospecialty_JJRC(
    IN s_cperiod varchar, 
    INOUT result int4, 
    INOUT msg text
)
AS $BODY$
DECLARE
    -- 规范变量声明：集中放置在BEGIN前，类型+默认值清晰
    s_pk_group VARCHAR(30) DEFAULT '';
    s_pk_book VARCHAR(30) DEFAULT '';
    s_pk_org VARCHAR(30) DEFAULT '';
    s_cperiod_year VARCHAR(30) DEFAULT '';
    s_cperiod_year_month VARCHAR(30) DEFAULT '';
 	s_cperiod_start_month VARCHAR(30) DEFAULT '';
    
    -- 数值型变量（初始化默认值）
    i INT DEFAULT 1;
    max_num INT DEFAULT 0;
    affected_rows INT DEFAULT 0;
    after_call_rows INT DEFAULT 0;
    skipItem VARCHAR(1000) DEFAULT '';
BEGIN
    -- 初始化返回值（默认成功）     
    result := 1;
    msg := concat(COALESCE(s_cperiod, '') ,'普药非新特药销售利润计算完成:');

    -- 1. 校验cperiod参数是否为空（替换IFNULL为COALESCE）
    IF COALESCE(s_cperiod, '') = '' THEN
        result := 0;
        msg := '参数未获取到';
        RETURN; -- 存储过程直接RETURN，无需参数
    END IF;

    -- 2. 拆分年月（PL/pgSQL赋值用:=）
    s_cperiod_year := split_part(s_cperiod, '-', 1); -- 会计年
    s_cperiod_year_month := split_part(s_cperiod, '-', 2); -- 会计月
	s_cperiod_start_month :=    concat(s_cperiod_year,'-01'); -- 初始月

    -- 3. 计算后的数据写入计算组（保留原业务逻辑，规范语法）
    -- 3.1 删除对应期间的数据
    DELETE FROM mis_auto_puyao_jyycmx WHERE cperiod = s_cperiod;

    -- 3.2 创建临时表（得到非特药的物料编码）
    DROP TABLE IF EXISTS temp_mis_auto_ldttj;
    CREATE TEMP TABLE IF NOT EXISTS temp_mis_auto_ldttj AS
    -- 第二步：对分层排序后的记录，按物料+销售部门+日期范围取第一条（去重）
	    SELECT * FROM (
	        -- 第一步：给底价记录标记优先级，按优先级+业务规则排序
	        SELECT 
	        si.id AS invoice_id,
	        up.price,
	        -- 定义优先级：有客户维度优先级高（1），否则低（2）
	        ROW_NUMBER() OVER (
	            PARTITION BY si.id 
	            ORDER BY 
	                CASE WHEN up.customer = lbvrh.name  THEN 1 ELSE 2 END, -- ,  -- 有客户维度优先
	                 mas.cperiod  asc  -- 若有多个，按日期取最新（可自定义）
	        ) AS rn
	    FROM mis_auto_ptpcr si
		left join mis_auto_yuorb dep on dep.pk_vid	 = si.cdeptvid  -- 部门
		left JOIN mis_auto_lbvrh lbvrh on lbvrh.pk_cust_sup_v	 = si.cinvoicecustid -- 客户
		LEFT JOIN mis_auto_ldttj mas 
		    ON mas.cperiod = si.cperiod 
		    AND mas.status = 1 
		    AND mas.isvoid = 0
		LEFT JOIN mis_auto_ldttj_sub_dijiamingxi up 
		    ON up.masid = mas.id  -- 通过已关联的 mas 来匹配 up
		    AND up.cinvcode = si.material_code
		    AND up.saledeptcode = dep.code
		    AND (up.customer = lbvrh.name OR up.customer IS NULL OR up.customer = '') 
		    AND up.isvoid = 0
        -- 仅保留有效价格（指定客户/通用价格）
        WHERE  si.cperiod >= s_cperiod_start_month and si.cperiod <= s_cperiod 
    ) t1
    WHERE t1.rn = 1; -- 去重：仅保留每组第一条


	 -- 3.2 创建临时表（得到物料的辅助计量单位）
    DROP TABLE IF EXISTS temp_mis_auto_tbdua;
    CREATE TEMP TABLE IF NOT EXISTS temp_mis_auto_tbdua AS
	    SELECT * FROM (
 
	        SELECT 
	        si.id AS invoice_id,
	      	mis_auto_tbdua.measrate,
	        -- 定义优先级：有客户维度优先级高（1），否则低（2）
	        ROW_NUMBER() OVER (
	            PARTITION BY si.id 
	            ORDER BY 
	                CASE WHEN  RIGHT(si.material_spec, 1) = mis_auto_tutyp.name  THEN 1 ELSE 2 END -- , 
	              
	        ) AS rn
	    FROM mis_auto_ptpcr si
		INNER JOIN   mis_auto_rbyld ON mis_auto_rbyld.pk_material = si.cmaterialvid  -- 物料基本信息
     	INNER JOIN mis_auto_tbdua ON mis_auto_rbyld.pk_material = mis_auto_tbdua.pk_material   -- 辅助计量
     	LEFT JOIN mis_auto_tutyp ON mis_auto_tutyp.pk_measdoc = mis_auto_tbdua.pk_measdoc   -- 计量单位西
        WHERE  si.cperiod >= s_cperiod_start_month and si.cperiod <= s_cperiod 
    ) t1
    WHERE t1.rn = 1; -- 去重：仅保留每组第一条


	-- 3.2.1 创建临时表（得到非特药的物料编码）
    DROP TABLE IF EXISTS temp_sale_cinv;
    CREATE TEMP TABLE IF NOT EXISTS temp_sale_cinv AS
 	select
	  pt.id 
	FROM
	  mis_auto_ptpcr pt
	LEFT JOIN mis_auto_xinteyao_lirun_mingxi xm
	  ON xm.jisuanqijian = s_cperiod AND xm.srcid = pt.id
	LEFT JOIN mis_auto_hlutv hl
	  ON hl.cperiod = s_cperiod AND hl.saleID = pt.id
	WHERE      pt.cperiod >= s_cperiod_start_month and pt.cperiod <= s_cperiod
	AND xm.srcid IS NULL
	AND hl.saleID IS NULL
	group by pt.id;


    -- 3.3 插入普药非新特药品种销售利润数据（规范列名和函数）
    INSERT INTO mis_auto_puyao_jyycmx(
        orderno, cperiod, fapiaoqijian,csaleinvoiceid, csaleinvoicecode, cinvoicecustid,
        firstvbillcode, vdef__1, vdef__2, vdef__3, name_2, name_5,
        area_class2, name_6, sales_channel, sales_channep, area_class,
        area_name2, vbillcode, vdef__5, drugstype, cmaterialvid,
        material_code, material_name, material_spec, nnum, quantity,
        norigtaxprice1, norigtaxnetprice, norigmny1, ntotalincomemny, norigsubmny1,
        ntotalincomemny1, norigdiscount1, cdq_je_bhs, unitbaseprice, minimumpriceamount,
        rowpknum, srcid,status, companyid, createid, allnode, createtime, isVoid
    )
    SELECT
        vbillcode AS orderno,
        s_cperiod as cperiod,
		mis_auto_ptpcr.cperiod as fapiaoqijian,
        mis_auto_ptpcr.csaleinvoiceid1 AS csaleinvoiceid,
        mis_auto_ptpcr.vbillcode AS csaleinvoicecode,
        mis_auto_ptpcr.cinvoicecustid,
        mis_auto_ptpcr.firstvbillcode,
        mis_auto_ptpcr.vdef__1 AS 金税票号, 
        mis_auto_ptpcr.vdef__2 AS 金税开票日期,          
        mis_auto_ptpcr.vdef__3 AS 实际出库日期,         
        mis_auto_ptpcr.name_2 AS 开票客户,              
        mis_auto_yuorb.name AS 销售部门,              
        CASE 
            WHEN mis_auto_ptpcr.area_name2 IN ('四川省', '重庆市') THEN '川渝' 
            ELSE '省外' 
        END AS area_class2,  -- 销售部门对应地区
        mis_auto_ptpcr.name_6 AS 销售业务员,            
        mis_auto_ptpcr.sales_channel AS 销售渠道,       
        mis_auto_ptpcr.sales_channel AS sales_channep,  -- 渠道业务员
        mis_auto_ptpcr.area_class AS 地区分类,          
        mis_auto_ptpcr.area_name2 AS 省市区,           
        mis_auto_ptpcr.num AS 凭证号,                  
        mis_auto_ptpcr.vdef__5 AS 业态,                
        '普药非新特药' AS drugstype,  -- 品种类型
        mis_auto_ptpcr.cmaterialvid, -- 物料主键
        mis_auto_ptpcr.material_code, -- 物料编码
        mis_auto_ptpcr.material_name, -- 物料名称
        mis_auto_ptpcr.material_spec, -- 规格
        mis_auto_ptpcr.nnum, -- 主数量
        COALESCE(cast (mis_auto_ptpcr.nnum AS numeric(18,8)), 0) / split_part(mis_auto_tbdua.measrate, '/', 1) AS quantity, -- 件数（替换IFNULL为COALESCE）
        mis_auto_ptpcr.norigtaxprice1, -- 主含税单价
        mis_auto_ptpcr.norigtaxnetprice, -- 主含税净价
        mis_auto_ptpcr.norigmny1, -- 无税金额合计
        mis_auto_ptpcr.ntotalincomemny, -- 价税合计
        mis_auto_ptpcr.norigsubmny1, -- 费用冲抵金额
        ( COALESCE(cast (mis_auto_ptpcr.ntotalincomemny AS numeric(18,8)),0 ) +   COALESCE(cast (mis_auto_ptpcr.norigsubmny1 AS numeric(18,8)), 0))  冲抵前金额, -- 冲抵前金额（ntotalincomemny1）
        mis_auto_ptpcr.norigdiscount1, -- 折扣额
       ( COALESCE(cast (mis_auto_ptpcr.ntotalincomemny AS numeric(18,8)),0 ) +   COALESCE(cast (mis_auto_ptpcr.norigsubmny1 AS numeric(18,8)), 0)) / 1.13 AS cdq_je_bhs, -- 冲抵前金额不含税
        temp_mis_auto_ldttj.price AS unitbaseprice, -- 单位底价
        COALESCE(cast (mis_auto_ptpcr.nnum AS numeric(18,8)), 0) * COALESCE(cast (temp_mis_auto_ldttj.price AS numeric(18,8)), 0) AS minimumpriceamount, -- 底价金额
        mis_auto_ptpcr.rowpknum,
   		mis_auto_ptpcr.id,
        1 AS status,
        1 AS companyid,
        1 AS createid,
        'MisAutoSow' AS allnode,
        EXTRACT(EPOCH FROM CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Shanghai') AS createtime, -- 时间戳转秒数
        0 AS isVoid	
    FROM mis_auto_ptpcr
	inner join temp_sale_cinv AS B ON B.id = mis_auto_ptpcr.id 
   --  LEFT JOIN mis_auto_rbyld ON mis_auto_rbyld.pk_material = mis_auto_ptpcr.cmaterialvid  -- 物料基本信息
    LEFT JOIN  temp_mis_auto_tbdua mis_auto_tbdua ON mis_auto_ptpcr.id = mis_auto_tbdua.invoice_id  -- 辅助计量
    LEFT JOIN mis_auto_yuorb ON mis_auto_ptpcr.cdeptvid = mis_auto_yuorb.pk_vid  -- 部门
    LEFT JOIN mis_auto_lbvrh ON mis_auto_ptpcr.cinvoicecustid = mis_auto_lbvrh.pk_cust_sup_v  -- 客户
    LEFT JOIN temp_mis_auto_ldttj ON temp_mis_auto_ldttj.invoice_id = mis_auto_ptpcr.id     
    WHERE mis_auto_ptpcr.cperiod >= s_cperiod_start_month  and  mis_auto_ptpcr.cperiod <= s_cperiod ;

	-- 更新单位底价
	UPDATE mis_auto_puyao_jyycmx tgt
	SET
		unitbaseprice = src.unitbaseprice,
		minimumpriceamount = src.minimumpriceamount
	FROM mis_auto_ptpcr ptpcr
	INNER JOIN mis_auto_puyao_jyycmx src 
		ON src.srcid = ptpcr.id 
		AND src.cperiod = ptpcr.cperiod   -- 源表的期间 = 明细的实际发生期间
	WHERE tgt.cperiod = s_cperiod         -- 目标期间为当前累计月份，例如 '2025-03'
	  AND tgt.srcid = ptpcr.id            -- 目标行对应的明细ID
	  AND ptpcr.cperiod < s_cperiod;      -- 仅处理实际发生期间早于目标期间的明细
 

  --  3.4 更新计算当期票折以及 两票制
		  -- =============================================
			-- 第1步：批量更新 订单冲抵金额、数量(按srcid汇总)
			-- =============================================
			UPDATE mis_auto_puyao_jyycmx t
			SET dingdanchongdijine = COALESCE(tmp.sum_ndiscount, 0),
				dingdanshuliang    = COALESCE(tmp.sum_nnum, 0)
			FROM (
				SELECT
					p.id AS srcid,
					SUM(b.nnum) AS sum_nnum,
					SUM(b.ndiscount) AS sum_ndiscount
				FROM mis_auto_ptpcr p
				INNER JOIN mis_auto_emwtt o ON o.vbillcode = p.firstvbillcode
				INNER JOIN mis_auto_emwtt_sub_csaleorderbid b ON o.csaleorderid = b.csaleorderid
				WHERE p.cmaterialvid = b.cmaterialid
				GROUP BY p.id
			) tmp
			WHERE t.srcid = tmp.srcid
		   AND t.cperiod = s_cperiod
			  ;

			-- =============================================
			-- 第2步：批量更新 发票+物料汇总金额、数量
			-- =============================================
			UPDATE mis_auto_puyao_jyycmx t
			SET fpwlhzchongdijine = COALESCE(tmp.sum_jine, 0),
				fpwlhzshuliang    = COALESCE(tmp.sum_shuliang, 0)
			FROM (
				SELECT
					mis_auto_puyao_jyycmx.csaleinvoiceid,
					mis_auto_puyao_jyycmx.material_code,
					SUM(dingdanchongdijine) AS sum_jine,
					SUM(dingdanshuliang)    AS sum_shuliang
				FROM mis_auto_puyao_jyycmx
				
				/*(select  mis_auto_puyao_jyycmx.csaleinvoiceid,
							  mis_auto_puyao_jyycmx.material_code,
					(dingdanchongdijine) AS dingdanchongdijine,
					(dingdanshuliang)    AS dingdanshuliang from mis_auto_puyao_jyycmx group by csaleinvoiceid,material_code,dingdanchongdijine,dingdanshuliang) mis_auto_puyao_jyycmx*/
				WHERE cperiod = s_cperiod
				GROUP BY csaleinvoiceid, material_code
			) tmp
			WHERE t.csaleinvoiceid = tmp.csaleinvoiceid
			  AND t.material_code = tmp.material_code
			  AND t.cperiod = s_cperiod
			  ;

			-- =============================================
			-- 第3步：统一计算 票折分摊单价
			-- =============================================
			UPDATE mis_auto_puyao_jyycmx
			SET dangqipiaozhefentand = CASE WHEN COALESCE(fpwlhzshuliang, 0) <> 0
										   THEN fpwlhzchongdijine / fpwlhzshuliang
										   ELSE 0 END
			WHERE cperiod = s_cperiod
			;

			-- =============================================
			-- 第4步：统一计算 当期票折(负数)
			-- =============================================
			UPDATE mis_auto_puyao_jyycmx
			SET dq_pz = COALESCE(nnum, 0) * COALESCE(dangqipiaozhefentand, 0) * -1
			WHERE cperiod = s_cperiod
			;

			-- =============================================
			-- 第5步：单位底价为0 → 清空相关字段
			-- 修复你原代码错误：i 是变量,不能直接写在SQL里
			-- =============================================
			UPDATE mis_auto_puyao_jyycmx d
			SET
				sw_lpz_sr = ( COALESCE(i.ntotalincomemny, 0) - COALESCE(i.minimumpriceamount, 0)   ) / 1.13,
				lpz_sr_hj = ( COALESCE(i.ntotalincomemny, 0) - COALESCE(i.minimumpriceamount, 0)   ) / 1.13,
				sw_lpz_sr_hj = ( COALESCE(i.ntotalincomemny, 0) - COALESCE(i.minimumpriceamount, 0)   ) / 1.13,
				js_lpz_fy = ( ( COALESCE(i.ntotalincomemny, 0) - COALESCE(i.minimumpriceamount, 0)  ) * 0.87115 ),
				zs_lpz_fy = ( ( COALESCE(i.ntotalincomemny, 0) - COALESCE(i.minimumpriceamount, 0)   ) * 0.87115 )
			FROM mis_auto_puyao_jyycmx i
			INNER JOIN mis_auto_ptpcr ptpcr
				ON i.srcid = ptpcr.id
				AND i.cperiod = ptpcr.cperiod
			WHERE d.csaleinvoiceid = i.csaleinvoiceid
				AND d.srcid = i.srcid -- 关联缺失的表
			   --  AND d.csaleinvoiceid = s_csaleinvoiceid1
				AND i.cperiod = s_cperiod
				AND ptpcr.cperiod = s_cperiod;
		 
		 
			UPDATE mis_auto_puyao_jyycmx
			SET sw_lpz_sr   = 0,
				lpz_sr_hj   = 0,
				js_lpz_fy   = 0,
				sw_lpz_sr_hj = 0,
				zs_lpz_fy   = 0
			WHERE cperiod = s_cperiod AND 
			  COALESCE(unitbaseprice, 0) = 0;

		     

			-- 异号清零
			UPDATE mis_auto_puyao_jyycmx
			SET lpz_sr_hj = 0
			WHERE cperiod = s_cperiod
			  AND COALESCE(lpz_sr_hj, 0) + COALESCE(ntotalincomemny1, 0) = 0;
 

    --  5. 调用子存储过程：计算跨期票折
		IF s_cperiod_year != '2025' THEN 


				CALL public.Cost_Data_Cost_Sales_Nospecialty_Drugs_JYYC_levels3(s_cperiod, v_sub_result, v_sub_msg);
				
				with tmp_fdq_agg AS(
					SELECT 
						target_srcid,
						denominator ,
						SUM(alloc_fdq_amount) * -1 AS alloc_fdq_amount,
						SUM(alloc_fdqb_amount) * -1 AS alloc_fdqb_amount
					FROM tmp_conversion_allocation_normal
					GROUP BY target_srcid
				)
				update mis_auto_puyao_jyycmx ib
				set 
					fdq_ftamount = 0 	-- 非当期补当期分摊总金额 
					,fdq_ftnum = nor.denominator	    -- 非当期补当期分摊总数量	
					,fdq_pz = nor.alloc_fdq_amount  
					,fdq_pz_bcdq =  nor.alloc_fdqb_amount 
				from tmp_fdq_agg nor 
				where  nor.target_srcid = ib.srcid 
					and ib.cperiod = s_cperiod;
				
				with tmp_fdqb_agg AS(
					SELECT 
						target_srcid,
						target_amount ,
						SUM(alloc_fdq_amount) * -1 AS alloc_fdq_amount,
						SUM(alloc_fdqb_amount) * -1 AS alloc_fdqb_amount
					FROM tmp_conversion_allocation_fallback
					GROUP BY target_srcid
				)
				-- 更新均摊票折
				update mis_auto_puyao_jyycmx ib
				set 
					fdqb_ftamount = fa.target_amount 	-- 非当期补当期分摊总金额 
					,fdqb_ftnum = 0 	    -- 非当期补当期分摊总数量	
					,fdq_pz_jt = fa.alloc_fdq_amount  
					,fdq_pz_bcdq_jt =  fa.alloc_fdqb_amount 
				from tmp_fdqb_agg   fa 
				where  fa.target_srcid = ib.srcid
					and ib.cperiod = s_cperiod;

				-- 更新票折合计
				update mis_auto_puyao_jyycmx ib  
					set  fdq_pz_hj = COALESCE(fdq_pz,0) + COALESCE(fdq_pz_jt,0)
						,fdq_pz_bcdq_hj = COALESCE(fdq_pz_bcdq,0) + COALESCE(fdq_pz_bcdq_jt,0)
						,fdq_pz_bcdq_bhs = (COALESCE(fdq_pz_bcdq,0) + COALESCE(fdq_pz_bcdq_jt,0))/1.13
						,fdq_pz_bhs =  (COALESCE(fdq_pz,0) + COALESCE(fdq_pz_jt,0)) /1.13
				where  ib.cperiod = s_cperiod;

			END IF;

			RAISE NOTICE '更新票折合计，开始处理: ';
			-- ========== 6. 更新票折合计 ==========
			UPDATE mis_auto_puyao_jyycmx
			SET pz_hj = COALESCE(dq_pz, 0) + COALESCE(fdq_pz_bcdq_hj, 0) + COALESCE(fdq_pz_hj, 0)
			WHERE cperiod = s_cperiod;
			
			
    IF result <> 1 THEN
        result := -1;
        msg := CONCAT('计算销售利润费用明细失败:', COALESCE(msg, '')); 
        RETURN;
    END IF; 



-- 全局异常处理
EXCEPTION
    WHEN OTHERS THEN
        result := -1;
        msg := CONCAT('普药非新特药销售利润计算失败:', SQLERRM); 
        RAISE NOTICE '异常信息：%，事务ID：%', SQLERRM, txid_current();
END;
$BODY$
LANGUAGE plpgsql;

