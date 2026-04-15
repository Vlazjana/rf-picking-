FUNCTION z_ewm_rf_pick_pihuin_pm_pbo.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(SELECTION) TYPE  /SCWM/S_RF_SELECTION
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC
*"     REFERENCE(RSRC_TYPE) TYPE  /SCWM/S_TRSRC_TYP
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"     REFERENCE(RF_PICK_HUS) TYPE  /SCWM/S_RF_PICK_HUS
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS
*"     REFERENCE(NESTPT) TYPE  /SCWM/S_RF_NESTED
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"----------------------------------------------------------------------


  DATA    lv_leave_trans         TYPE xfeld VALUE IS INITIAL.
* Pick HUs screen

  DATA: lv_postn_mngmnt TYPE /scwm/de_postn.
  DATA: lv_tabix LIKE sy-tabix.
  DATA: lv_lines TYPE sy-tabix.
  DATA: lv_changed_huhdr TYPE xfeld.
  DATA: lv_found_empty_verif TYPE xfeld.
  DATA: ls_trsrc_typ TYPE /scwm/trsrc_typ.
  DATA: ls_huhdr TYPE /scwm/s_huhdr_int.
  DATA: ls_whohu TYPE /scwm/s_whohu.
  DATA: lt_whohu TYPE /scwm/tt_whohu_int.
  DATA: oref TYPE REF TO /scwm/cl_wm_packing.
  DATA: ls_rf_pick_hus TYPE /scwm/s_rf_pick_hus.
  DATA: lv_numc2 TYPE numc2.
  DATA: ls_mat_global TYPE /scwm/s_material_global.
  DATA: ls_range   TYPE rsdsselopt,
        lr_huident TYPE rseloption,
        lt_huhdr   TYPE /scwm/tt_huhdr_int.
  DATA: ls_text        TYPE /scwm/s_rf_text.
  DATA: lt_text        TYPE /scwm/tt_rf_text.
  DATA: lv_fcode       TYPE /scwm/de_fcode.

  DATA: ls_ordim_confirm TYPE /scwm/s_rf_ordim_confirm.
  DATA: ls_docid_tab   TYPE /scwm/dlv_docid_item_str.
  DATA: lt_docid_tab   TYPE /scwm/dlv_docid_item_tab.
  DATA: lv_pickhu_skip TYPE /scwm/de_rf_skiphu.
  DATA: lv_data_entry  TYPE /scwm/de_data_entry.
  DATA: lt_ordim_c     TYPE /scwm/tt_ordim_c.
  DATA: ls_twcr        TYPE /scwm/twcr.

  FIELD-SYMBOLS: <nested_hu> TYPE /scwm/s_rf_pick_hus.
  FIELD-SYMBOLS: <pick_hu> TYPE /scwm/s_rf_pick_hus.

  BREAK-POINT ID /scwm/rf_picking.

  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).
*  lv_line = /scwm/cl_rf_bll_srvc=>get_line( ).
  lv_data_entry = /scwm/cl_rf_bll_srvc=>get_data_entry( ).

* Initiate screen parameter
  /scwm/cl_rf_bll_srvc=>init_screen_param( ).
* Set screen current line
  /scwm/cl_rf_bll_srvc=>set_line('1').
* Set screen parameter
  /scwm/cl_rf_bll_srvc=>set_screen_param('WHO').
* Set screen parameter
  /scwm/cl_rf_bll_srvc=>set_screen_param('ORDIM_CONFIRM').
* Set screen parameter
  /scwm/cl_rf_bll_srvc=>set_screen_param('T_RF_PICK_HUS').
* Set screen parameter
  /scwm/cl_rf_bll_srvc=>set_screen_param('NESTPT').


* Create instance
      CREATE OBJECT oref.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
** call the stack optimizer to save memory
  CALL METHOD /scwm/cl_rf_bll_srvc=>set_call_stack_optimizer
    EXPORTING
      iv_step = 'ZPI2'.

 CASE lv_fcode.

    WHEN fcode_backf.

      CALL FUNCTION '/SCWM/RF_PICK_BACKF_CHECK'
        CHANGING
          tt_ordim_confirm = tt_ordim_confirm
          lv_leave_trans   = lv_leave_trans.

      IF NOT lv_leave_trans IS INITIAL.
        CALL FUNCTION 'Z_EWM_RF_PICK_LEAVE_TRNS_CHCK'
          CHANGING
            who              = who
            resource         = resource
            ordim_confirm    = ordim_confirm
            tt_ordim_confirm = tt_ordim_confirm.
        EXIT.
      ELSE.
        EXIT.
      ENDIF.

      ENDCASE.

      lv_tabix = sy-tabix.
      /scwm/cl_rf_bll_srvc=>set_screlm_input_off(
        iv_screlm_name = gc_pmat
        iv_index = lv_tabix ).
      /scwm/cl_rf_bll_srvc=>set_screlm_input_off(
        iv_screlm_name = gc_huident
        iv_index = lv_tabix ).
      IF lv_postn_mngmnt = gc_manual_postn_mng AND <nested_hu>-logpos IS INITIAL.
        /scwm/cl_rf_bll_srvc=>set_screlm_input_on(
          iv_screlm_name = gc_logpos
          iv_index = lv_tabix ).
      ELSE.
        /scwm/cl_rf_bll_srvc=>set_screlm_input_off(
          iv_screlm_name = gc_logpos
          iv_index = lv_tabix ).
      ENDIF.

*    " make visible field.
      /scwm/cl_rf_bll_srvc=>set_screlm_invisible_ON(
                            '/SCWM/S_RF_ORDIM_CONFIRM-TEXT_SCR' ).

    ENDFUNCTION.
