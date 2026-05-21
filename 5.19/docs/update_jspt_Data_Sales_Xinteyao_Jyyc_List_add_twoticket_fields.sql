DROP VIEW IF EXISTS public."jspt_Data_Sales_Xinteyao_Jyyc_List";

CREATE VIEW public."jspt_Data_Sales_Xinteyao_Jyyc_List" AS
SELECT
    m.hesuanqijian AS "会计期间",
    m.chukudanjuriqi AS "开票日期",
    m.jinshuipiaohao AS "金税票号",
    m.jinshuikaipiaoriqi AS "金税开票日期",
    m.shijichukuriqi AS "实际出库日期",
    m.kaipiaokehu AS "开票客户",
    m.xiaoshoubumen AS "销售部门",
    m.xiaoshouyewuyuan AS "销售业务员",
    m.xiaoshouqudao AS "销售渠道",
    m.qudaoyewuyuan AS "渠道业务员",
    m.diqufenlei AS "地区分类",
    m.shengshiqu AS "省市区",
    m.yetai AS "业态",
    m.pinzhongleixing AS "品种类型",
    m.pingzhenghao AS "凭证号",
    m.wuliaobianma AS "物料编码",
    m.wuliaomingcheng AS "物料名称",
    m.guige AS "规格",
    m.zhushuliang AS "主数量",
    m.jianshu AS "件数",
    m.zhuhanshuidanjia AS "主含税单价",
    m.zhuhanshuijingjia AS "主含税净价",
    m.wushuijineheji AS "无税金额合计",
    m.kuaqiwushuitiaozheng AS "跨期票折还原本期销售收入",
    m.wushuijinezonge AS "收入还原不含税",
    m.jiashuiheji AS "价税合计",
    m.feiyongchongdijine AS "费用冲抵金额",
    m.chongdiqianjine AS "冲抵前金额",
    m.zhekoue AS "折扣额",
    m.cdq_je_bhs AS "冲抵前金额不含税",
    m.danweidijia AS "单位底价",
    m.dijiajine AS "底价金额",
    m.dijiashouru AS "底价收入",
    m.kuaqidijiatiaozheng AS "跨期票折还原本期销售收入底价收入调整",
    m.dijiashouruheji AS "底价收入合计",
    m.gaokaijine AS "高开金额",
    m.gaokaishouru AS "高开收入",
    m.kuaqigaokaitiaozheng AS "跨期票折还原本期销售收入高开收入调整",
    m.gaokaishouruheji AS "高开收入合计",
    m.sw_lpz_sr AS "省外两票制收入",
    m.sw_lpz_sr_tz AS "省外两票制收入调整",
    m.sw_lpz_sr_hj AS "省外两票制收入合计",
    m.cy_lpz_sr AS "川渝两票制收入",
    m.lpz_sr_hj AS "两票制收入合计",
    m.jisuanliangpiaozhifeiyong AS "计算两票制费用",
    m.zs_lpz_fy AS "最终两票制费用",
    m.dq_pz AS "当期票折",
    m.dq_pz_bhs AS "当期票折不含税",
    m.bhdq_pz_cdq_bhs AS "冲减非当期折扣前的底价收入",
    m.fdq_pz_bcdq AS "非当期票折（补当期）品规明细",
    m.fdq_pz_bcdq_jt AS "非当期票折（补当期）公摊",
    m.fdq_pz_bcdq_hj AS "非当期票折（补当期）合计",
    m.fdq_pz_bcdq_bhs AS "非当期票折（补当期）不含税",
    m.fdq_pz AS "非当期票折品规明细",
    m.fdq_pz_jt AS "非当期票折公摊",
    m.fdq_pz_hj AS "非当期票折合计",
    m.fdq_pz_bhs AS "非当期票折不含税",
    m.pz_hj AS "票折合计",
    m.xiaoshoushouru AS "销售收入",
    m.xiaoshoujine AS "销售金额",
    m.dijiashouru087115 AS "底价收入（0.87115口径）",
    m.fachushangpindaifangdanjia AS "发出商品贷方单价",
    m.fachushangpinchengben AS "发出商品成本",
    m.ncpkouchujishu AS "农产品扣除基数",
    m.ncpjiajikouchu AS "农产品加计扣除",
    SUM(COALESCE(m.ncpjiajikouchu, 0)) OVER (PARTITION BY m.hesuanqijian, m.pinzhongleixing) AS "农产品加计扣除总额",
    CASE
        WHEN COALESCE(m.zhushuliang, 0) = 0 THEN 0
        ELSE ROUND(COALESCE(m.yunfei, 0) / NULLIF(m.zhushuliang, 0), 8)
    END AS "单位运费",
    m.zongyunfei AS "总运费",
    m.yunfei AS "运费",
    m.zhuyingyewuchengben AS "主营业务成本",
    ROUND(COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0), 8) AS "底价毛利额",
    CASE
        WHEN COALESCE(m.dijiashouru087115, 0) = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0))
            / NULLIF(m.dijiashouru087115, 0),
            8
        )
    END AS "底价毛利率",
    CASE
        WHEN ROUND(COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0), 8) = 0 THEN NULL
        WHEN COALESCE(m.dijiashouru087115, 0) = 0 THEN NULL
        WHEN (
            (COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0))
            / NULLIF(m.dijiashouru087115, 0)
        ) > 1
          OR (
            (COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0))
            / NULLIF(m.dijiashouru087115, 0)
        ) < 0 THEN '负'
        WHEN (
            (COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0))
            / NULLIF(m.dijiashouru087115, 0)
        ) > 0.45 THEN '高'
        WHEN (
            (COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0))
            / NULLIF(m.dijiashouru087115, 0)
        ) >= 0.30
          AND (
            (COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0))
            / NULLIF(m.dijiashouru087115, 0)
        ) <= 0.45 THEN '中'
        WHEN (
            (COALESCE(m.dijiashouru087115, 0) - COALESCE(m.zhuyingyewuchengben, 0))
            / NULLIF(m.dijiashouru087115, 0)
        ) < 0.30 THEN '低'
        ELSE NULL
    END AS "底价毛利区间",
    m.yucelixingfeiyonglv AS "例行费用率",
    m.erjizhanglixingfeiyong AS "二级账例行费用（分品规（物料编码））",
    m.chuerjizhanglixingfeiyong AS "除二级账例行费用（只算鼻窦炎）",
    m.lixingfeiyongheji AS "例行费用合计",
    m.xiaoshoufeiyong AS "销售费用",
    m.yuceshuijinlv AS "税金及附加率",
    m.shuijinjifujia AS "税金及附加",
    m.yuceguanlilv AS "管理费用率",
    m.guanlifeiyong AS "管理费用",
    m.yuceyanfalv AS "研发费用率",
    m.yanfafeiyong AS "研发费用",
    m.yucecaiwulv AS "财务费用率",
    m.caiwufeiyong AS "财务费用",
    ROUND(
        COALESCE(m.shuijinjifujia, 0)
        + COALESCE(m.guanlifeiyong, 0)
        + COALESCE(m.yanfafeiyong, 0)
        + COALESCE(m.caiwufeiyong, 0),
        8
    ) AS "其他费用",
    ROUND(
        COALESCE(m.wushuijinezonge, 0)
        - COALESCE(m.zhuyingyewuchengben, 0)
        - COALESCE(m.xiaoshoufeiyong, 0),
        8
    ) AS "销售利润",
    ROUND(
        COALESCE(m.wushuijinezonge, 0)
        - COALESCE(m.zhuyingyewuchengben, 0)
        - COALESCE(m.xiaoshoufeiyong, 0)
        - (
            COALESCE(m.shuijinjifujia, 0)
            + COALESCE(m.guanlifeiyong, 0)
            + COALESCE(m.yanfafeiyong, 0)
            + COALESCE(m.caiwufeiyong, 0)
        ),
        8
    ) AS "利润"
FROM public.mis_auto_jyycmx m
ORDER BY m.chukudanjuriqi NULLS FIRST, m.wuliaobianma NULLS FIRST;
