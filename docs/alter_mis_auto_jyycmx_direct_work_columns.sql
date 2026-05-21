-- Direct public.mis_auto_jyycmx support columns only.
-- Do not add duplicated source aliases such as vdef__1/name_2/material_code/nnum.
ALTER TABLE public.mis_auto_jyycmx
    ADD COLUMN IF NOT EXISTS fapiaoqijian varchar,
    ADD COLUMN IF NOT EXISTS xiaoshoubumenduiyingdiqu varchar,
    ADD COLUMN IF NOT EXISTS pinzhong varchar,
    ADD COLUMN IF NOT EXISTS cinvoicecustid varchar,
    ADD COLUMN IF NOT EXISTS firstvbillcode varchar,
    ADD COLUMN IF NOT EXISTS cmaterialvid varchar,
    ADD COLUMN IF NOT EXISTS cdq_je_bhs numeric(24,8),
    ADD COLUMN IF NOT EXISTS dq_pz numeric(24,8),
    ADD COLUMN IF NOT EXISTS dq_pz_bhs numeric(24,8),
    ADD COLUMN IF NOT EXISTS bhdq_pz_cdq_bhs numeric(24,8),
    ADD COLUMN IF NOT EXISTS sw_lpz_sr numeric(24,8),
    ADD COLUMN IF NOT EXISTS sw_lpz_sr_tz numeric(24,8),
    ADD COLUMN IF NOT EXISTS sw_lpz_sr_hj numeric(24,8),
    ADD COLUMN IF NOT EXISTS cy_lpz_sr numeric(24,8),
    ADD COLUMN IF NOT EXISTS lpz_sr_hj numeric(24,8),
    ADD COLUMN IF NOT EXISTS js_lpz_fy numeric(24,8),
    ADD COLUMN IF NOT EXISTS zs_lpz_fy numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz_bcdq numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz_bcdq_jt numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz_bcdq_hj numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz_bcdq_bhs numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz_jt numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz_hj numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_pz_bhs numeric(24,8),
    ADD COLUMN IF NOT EXISTS pz_hj numeric(24,8),
    ADD COLUMN IF NOT EXISTS kuaqipiaozhexiaoshou numeric(24,8),
    ADD COLUMN IF NOT EXISTS fdq_ftamount varchar,
    ADD COLUMN IF NOT EXISTS fdq_ftnum varchar,
    ADD COLUMN IF NOT EXISTS fdqb_ftamount varchar,
    ADD COLUMN IF NOT EXISTS fdqb_ftnum varchar,
    ADD COLUMN IF NOT EXISTS orderseq integer;

CREATE INDEX IF NOT EXISTS idx_jyycmx_direct_hesuanqijian_pinzhongleixing
    ON public.mis_auto_jyycmx (hesuanqijian, pinzhongleixing);

CREATE INDEX IF NOT EXISTS idx_jyycmx_direct_srcid
    ON public.mis_auto_jyycmx (srcid);

CREATE INDEX IF NOT EXISTS idx_jyycmx_direct_csaleinvoiceid1
    ON public.mis_auto_jyycmx (csaleinvoiceid1);

CREATE INDEX IF NOT EXISTS idx_jyycmx_direct_wuliaobianma
    ON public.mis_auto_jyycmx (wuliaobianma);
