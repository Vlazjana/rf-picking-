FUNCTION z_ewm_rf_pick_pibsys_pbo.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"     REFERENCE(WME_VERIF) TYPE  /SCWM/S_WME_VERIF
*"     REFERENCE(S_WHO_SCREEN) TYPE  ZSRF_ZPISYS_WHO_SCREEN
*"     REFERENCE(SELECTION) TYPE  /SCWM/S_RF_SELECTION
*"     REFERENCE(ZT_WHO_SCREEN) TYPE  ZTTRF_ZPISYS_WHO_SCREEN
*"     REFERENCE(NESTPT) TYPE  /SCWM/S_RF_NESTED
*"     REFERENCE(RSRC_TYPE) TYPE  /SCWM/S_TRSRC_TYP
*"----------------------------------------------------------------------
DATA: lv_fcode TYPE /scwm/de_fcode.
  DATA: lv_lines TYPE sy-tabix.
  DATA: ls_t340d TYPE /scwm/t340d.
  DATA: ls_huhdr TYPE /scwm/s_huhdr_int.
  DATA: lt_new_pick_hus TYPE /scwm/tt_rf_pick_hus.
  DATA: oref TYPE REF TO /scwm/cl_wm_packing.
  DATA: lv_applic        TYPE /scwm/de_applic,
        lv_pres_prf      TYPE /scwm/de_pres_prf,
        lv_ltrans        TYPE /scwm/de_ltrans,
        lv_step          TYPE /scwm/de_step,
        lv_state         TYPE /scwm/de_state,
        lv_return        TYPE sy-subrc,
        ls_ordim_confirm TYPE /scwm/s_rf_ordim_confirm,
        ls_huhdr_x       TYPE /scwm/huhdr,
        ls_who           TYPE /scwm/who,
        lt_ordim_o       TYPE /scwm/tt_ordim_o,
        ls_ordim_o       TYPE /scwm/ordim_o.
  DATA: lo_badi TYPE REF TO /scwm/ex_rf_prt_wo_hu.

  DATA: lt_text   TYPE tdtab_c132.

  FIELD-SYMBOLS: <pick_hu> TYPE /scwm/s_rf_pick_hus.

  BREAK-POINT ID /scwm/rf_picking.

* Get fcode
  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).

* First Delete /Reset the DLV Text
  CLEAR: lt_text.
  CALL METHOD /scwm/cl_rf_bll_srvc=>set_rf_text
    EXPORTING
      it_text = lt_text.
    /scwm/cl_rf_bll_srvc=>set_flg_stack( iv_flg_stack = ' ' ).

  CASE lv_fcode.
    WHEN 'FCBACK'.
*   *     FIRST thing - prevent ZPI1 from being pushed to stack

*     Then do your checks
      CALL FUNCTION 'Z_EWM_RF_PICK_LEAVE_TRNS_CHCK'
        CHANGING
          who              = who
          resource         = resource
          ordim_confirm    = ordim_confirm
          tt_ordim_confirm = tt_ordim_confirm.
*
      who-status = ' '.
      gv_selected_who = who-who.
      /scwm/cl_rf_bll_srvc=>set_fcode_on( iv_fcode = 'ZHUCR' ).

*     Clear everything
      CLEAR: who,
             resource,
             ordim_confirm,
             nestpt,
             s_who_screen,
             zt_who_screen,
             t_rf_pick_hus.

*    WHEN 'NEXT'.
*
*      CALL FUNCTION '/SCWM/RF_PRINT_GLOBAL_DATA'.
*
*      IF who-type = wmegc_wcr_dd.
*        BREAK-POINT ID /scwm/dd_picking.
** Distribution Device:
**DD1       check if user created a pick-HU
*        LOOP AT t_rf_pick_hus ASSIGNING <pick_hu>
*                   WHERE huident IS NOT INITIAL.
*          EXIT.
*        ENDLOOP.
*        IF sy-subrc IS NOT INITIAL.
**          MESSAGE e074." JQ
*        ENDIF.
**DD2: set state -> we need DD-screen to show DLOGPOS
*        lv_state = /scwm/cl_rf_bll_srvc=>get_state( ).
*        IF NOT ( lv_state = gc_PLHU OR lv_state = gc_plmt ).
*          /scwm/cl_rf_bll_srvc=>set_state( gc_dd_mtto ).
*        ENDIF.
*      ENDIF.
*
** Create instance
*      CREATE OBJECT oref.
*      IF sy-subrc <> 0.
*        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*      ENDIF.
*
*
** Read process type for HU-TO creation for inverse picking
*      CALL FUNCTION '/SCWM/T340D_READ_SINGLE'
*        EXPORTING
*          iv_lgnum = who-lgnum
*        IMPORTING
*          es_t340d = ls_t340d.
*
*      LOOP AT t_rf_pick_hus ASSIGNING <pick_hu>.
**   If position management is manual
*        IF rsrc_type-postn_mngmnt = gc_manual_postn_mng
*          AND <pick_hu>-logpos IS INITIAL.
**     Missing position for HU &1. Scan again and update
**      MESSAGE e066 WITH <pick_hu>-huident. "JQ
*        ENDIF.
*      ENDLOOP.
*
*
** Locate and move pick-HUs to resource
*      PERFORM locate_move_hus_to_resource
*        TABLES t_rf_pick_hus
*         USING who resource ls_t340d oref.
*
** Set actual function code for navigation to next step
*      CALL FUNCTION '/SCWM/RF_PICK_SET_FCODE'
*        CHANGING
*          resource         = resource
*          ordim_confirm    = ordim_confirm
*          tt_ordim_confirm = tt_ordim_confirm.
*
*      /scwm/cl_rf_bll_srvc=>set_line( 1 ).

  ENDCASE.
ENDFUNCTION.
