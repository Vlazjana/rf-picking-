FUNCTION ZEWM_SCWM_RF_PICK_BIN_CHECK.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IS_VALID_PRF) TYPE  /SCWM/S_VALID_PRF_EXT OPTIONAL
*"     REFERENCE(IV_FLG_VERIFIED) TYPE  XFELD OPTIONAL
*"  EXPORTING
*"     VALUE(EV_FLG_VERIFIED) TYPE  XFELD
*"  CHANGING
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"----------------------------------------------------------------------
* Verify entered storage bin against storage bin master data.
* Storage bin can be storage bin or verification field (LAGP-VERIF).
*
* No messages are raised. On any error 'EV_FLG_VERIFIED' should returned
*   with initial value.
* On case of convertion exits (named in IS_VERIF_PRF-CONVEXIT) we must
*   do the convertion by hand.

  DATA: ls_ordim_confirm  TYPE /scwm/s_rf_ordim_confirm,
        lv_step           TYPE /scwm/de_step,
        lv_ltrans         TYPE /scwm/de_ltrans,
        ls_lagp           TYPE /scwm/lagp,
        lv_string         TYPE char2,
        lc_ltrans_picking TYPE char2 VALUE 'ZP',
        lv_line           TYPE i.

  DATA: lv_lgpla          TYPE /scwm/de_lgpla,
        lv_data_entry     TYPE /scwm/de_data_entry.

  BREAK-POINT ID /scwm/rf_picking.

* Get logical transaction, step and actual line of the table.
  lv_ltrans = /scwm/cl_rf_bll_srvc=>get_ltrans( ).
  lv_string = lv_ltrans.
  lv_step = /scwm/cl_rf_bll_srvc=>get_step( ).
  lv_line = /scwm/cl_rf_bll_srvc=>get_line( ).

* Update the working structure with the actual data
  READ TABLE tt_ordim_confirm INDEX lv_line INTO ordim_confirm.

* Check if we work with a PbV device
  lv_data_entry = /scwm/cl_rf_bll_srvc=>get_data_entry( ).

* If we have a positive verification bin against bin from
*   the RF framework we leave the fm
  IF iv_flg_verified = /scmb/cl_c=>boole_true.
    "In PbV a 1 to 1 verification is only valid
    "  if no verification value is maintained in storage bin master
    IF lv_data_entry <> wmegc_data_entry_voice.
      ev_flg_verified = /scmb/cl_c=>boole_true.
      EXIT.
    ENDIF.
  ENDIF.

* If we have a positive verification bin against bin and
*   we are a PbV device                              and
*   we have a SKFD exception -> we leave the fm
  IF iv_flg_verified = /scmb/cl_c=>boole_true AND
     lv_data_entry = wmegc_data_entry_voice.
    READ TABLE ordim_confirm-exc_tab TRANSPORTING NO FIELDS
      WITH KEY iprcode = wmegc_iprcode_skfd.
    IF sy-subrc = 0. "Found a Skip Field Validation
      ev_flg_verified = /scmb/cl_c=>boole_true.
      RETURN.
    ENDIF.
  ENDIF.

* Read additional data
  FIELD-SYMBOLS <lv_scr_field> TYPE ANY.
  ASSIGN COMPONENT is_valid_prf-valval_fldname
         OF STRUCTURE ordim_confirm TO <lv_scr_field>.

  lv_lgpla = <lv_scr_field>.

  IF lv_data_entry = wmegc_data_entry_voice.
    IF  lv_step = 'PVMTTO' OR
        lv_step = step_pbv_cpmt OR
        lv_step = step_pbv_blcp OR
        lv_step = 'PVHUTO' OR
        lv_step = 'PVBLMT' OR
        lv_step = 'PVBLHU'.
      lv_lgpla = ordim_confirm-vlpla.
    ELSEIF lv_step = 'PVPLHU' OR
           lv_step = 'PVPLMT'.
      lv_lgpla = ordim_confirm-nlpla.
    ENDIF.
  ENDIF.

  CALL FUNCTION '/SCWM/LAGP_READ_SINGLE'
    EXPORTING
*      IV_GUID_LOC       =
      iv_lgnum          = ordim_confirm-lgnum
      iv_lgpla          = lv_lgpla
*      iv_nobuf          = 'X'
*      IV_ENQUEUE        =
    IMPORTING
*      EV_GUID_LOC       =
      es_lagp           = ls_lagp
    EXCEPTIONS
      wrong_input       = 1
      not_found         = 2
      OTHERS            = 3
                .
  IF sy-subrc <> 0.
    EXIT.
  ENDIF.

  IF lv_string = lc_ltrans_picking.
    IF  lv_step = step_source_mtto OR
        lv_step = step_pick_cpmt   OR
        lv_step = step_source_huto OR
        lv_step = step_source_blmt OR
        lv_step = step_source_blcp OR
*        lv_step = 'ZPICK6' OR
        lv_step = step_source_blhu.
      IF ordim_confirm-vlpla_verif = ls_lagp-verif.
        ev_flg_verified = /scmb/cl_c=>boole_true.
      ENDIF.
    ELSEIF lv_step = step_dest_plhu OR
           lv_step = step_dest_plmt OR
           lv_step = step_dest_mphu.
      IF ordim_confirm-nlpla_verif = ls_lagp-verif.
        ev_flg_verified = /scmb/cl_c=>boole_true.
      ELSEIF ordim_confirm-nlpla IS INITIAL.
        ordim_confirm-nlpla = ls_lagp-lgpla.
        ev_flg_verified = /scmb/cl_c=>boole_true.
      ENDIF.
    ENDIF.
  ENDIF.

* On Pick by Voice, for stack and aisle fields
* only 1-to-1 validation is allowed but level
* can be validate with storage bin.
* If the verfication field from bin master
* is filled this value is accepted too.
  IF lv_data_entry = wmegc_data_entry_voice.
    "Special logic only for level. All other fields have 1 to 1 verificaiton
    IF is_valid_prf-valid_obj = gc_valid_obj_level.
      IF ls_lagp-verif IS INITIAL AND
         ls_lagp-pbv_verif IS INITIAL.
        "Valid data is 1 to 1 and level can be storage bin
        IF iv_flg_verified IS NOT INITIAL OR  "1 to 1 verification
           ordim_confirm-lvl_v_verif = ls_lagp-lgpla.
          ev_flg_verified = /scmb/cl_c=>boole_true.
          EXIT.
        ENDIF.
      ELSEIF ls_lagp-verif IS NOT INITIAL AND
             ls_lagp-pbv_verif IS INITIAL.
        "Valid data is only RF verification value
        IF ordim_confirm-lvl_v_verif = ls_lagp-verif.
          ev_flg_verified = /scmb/cl_c=>boole_true.
          EXIT.
        ENDIF.
      ELSEIF ( ( ls_lagp-verif IS NOT INITIAL AND
                 ls_lagp-pbv_verif IS NOT INITIAL ) OR
               ( ls_lagp-verif IS INITIAL AND
                 ls_lagp-pbv_verif IS NOT INITIAL ) ).
        "Valid data is only PBV verification value
        IF ordim_confirm-lvl_v_verif = ls_lagp-pbv_verif.
          ev_flg_verified = /scmb/cl_c=>boole_true.
          EXIT.
        ENDIF.
      ENDIF.
    ELSE.
      IF iv_flg_verified IS NOT INITIAL.
        ev_flg_verified = /scmb/cl_c=>boole_true.
        EXIT.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFUNCTION.
