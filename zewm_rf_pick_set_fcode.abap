FUNCTION zewm_rf_pick_set_fcode.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC OPTIONAL
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT OPTIONAL
*"----------------------------------------------------------------------

  DATA: lv_fcode             TYPE /scwm/de_fcode,
        lv_step              TYPE /scwm/de_step,
        lv_ltrans            TYPE /scwm/de_ltrans,
        lv_state             TYPE /scwm/de_state,
        lv_string(2)         TYPE c,
        lc_ltrans_picking(2) TYPE c VALUE 'ZP',
        ls_ordim_confirm     TYPE /scwm/s_rf_ordim_confirm,
        lv_wo_full_hu_tos    TYPE xfeld VALUE gc_xfeld.

  DATA: lt_ordim_o TYPE /scwm/tt_ordim_o,
        lt_ordim_c TYPE /scwm/tt_ordim_c,
        ls_ordim_o TYPE /scwm/ordim_o,
        ls_who     TYPE /scwm/s_who_int,
        lt_who     TYPE /scwm/tt_who_int.

  DATA: ls_exc  TYPE /scwm/s_rf_exc,
        lv_line TYPE numc4,
        ls_t333 TYPE /scwm/t333.


  DATA cv_fcode TYPE /scwm/de_fcode.


* Get logical transaction, step, state and function code
  lv_ltrans = /scwm/cl_rf_bll_srvc=>get_ltrans( ).
  lv_step = /scwm/cl_rf_bll_srvc=>get_step( ).
  lv_state = /scwm/cl_rf_bll_srvc=>get_state( ).
  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).
* Cut ltrans - all picking transaction starts with PI.
  lv_string = lv_ltrans.

* Set process mode to background for changing fcode
  /scwm/cl_rf_bll_srvc=>set_prmod(
                             /scwm/cl_rf_bll_srvc=>c_prmod_background ).
gv_who = who-who.
* Set Fcode to next step after initial steps of transactions.
  IF ordim_confirm IS INITIAL.
    IF gv_dest_before_quit IS NOT INITIAL.
*     Get WO data
      TRY.
          CALL FUNCTION '/SCWM/WHO_SELECT'
            EXPORTING
              iv_to      = gc_xfeld
              iv_lgnum   = resource-lgnum
              iv_who     = gv_who
            IMPORTING
              es_who     = ls_who
              et_ordim_o = lt_ordim_o.
        CATCH /scwm/cx_core.
      ENDTRY.

      LOOP AT lt_ordim_o INTO ls_ordim_o.
        MOVE-CORRESPONDING ls_ordim_o TO ordim_confirm.
        EXIT.
      ENDLOOP.

*     WO started - split WO?
      CALL FUNCTION '/SCWM/RF_PICK_WHO_SPLIT'
        EXPORTING
          it_ordim_o       = lt_ordim_o
        CHANGING
          ordim_confirm    = ordim_confirm
          tt_ordim_confirm = tt_ordim_confirm.

    ELSE.
      IF gv_no_fup_wt IS INITIAL.

*     Get WO data and check whether the WO is ready to close.
*     if WHO has no open WT anymore, close it.
        CALL FUNCTION '/SCWM/WHO_UPDATE'
          EXPORTING
            iv_lgnum     = resource-lgnum
            iv_release   = 'C'
            iv_db_update = 'X'
            iv_who       = gv_who
          EXCEPTIONS
            read_error   = 1
            attributes   = 2
            OTHERS       = 3.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
           WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

        COMMIT WORK AND WAIT.
        CALL METHOD /scwm/cl_tm=>cleanup( ).

*     Set Fcode to complete transaction.
        /scwm/cl_rf_bll_srvc=>message(
                   iv_msg_view = gc_msg_view_scr
                   iv_flg_continue_flow = gc_xfeld
                   iv_msgid           = gc_picking_msgid
                   iv_msgty           = gc_msgty_warning
                   iv_msgno           = '043' ).

        /scwm/cl_rf_bll_srvc=>set_fcode(
                             /scwm/cl_rf_bll_srvc=>c_fcode_end_ltrans ).

*     Requesting RF Framework to release locks to cover cases where
*     locking of WO was done before calling RF picking transaction.
        /scwm/cl_rf_bll_srvc=>set_flg_dequeue_all( ).
      ELSE.
*     Get the next WHO from the queue
        PERFORM pick_return_navigation
         USING  lv_ltrans.
        CLEAR gv_no_fup_wt.
      ENDIF.
    ENDIF.
    EXIT.
  ENDIF.

  IF lv_string = lc_ltrans_picking.
    IF lv_step = step_pick_by_system OR
       lv_step = step_pick_by_user OR
       lv_step = step_pick_recovery.
*   If initial step of picking transaction
*     Check if all TOs are HU TOs in initial steps
      LOOP AT tt_ordim_confirm INTO ls_ordim_confirm.
        IF ls_ordim_confirm-flghuto <> gc_xfeld AND
           ls_ordim_confirm-srsrc IS INITIAL.
          CLEAR lv_wo_full_hu_tos.
        ENDIF.
      ENDLOOP.

*     Set Fcode Goto Pick HU introduction step.
      IF lv_wo_full_hu_tos IS INITIAL.
        lv_fcode = fcode_go_to_hu_int.
      ELSE.
*     Set fcode for correct source/destination step.
        IF ordim_confirm-srsrc IS INITIAL.
          IF lv_state = gc_huto.
            lv_fcode = fcode_go_to_pick_huto.
          ELSEIF lv_state = gc_bulk_huto.
            lv_fcode = fcode_go_to_pick_blhu.
          ENDIF.
        ELSEIF ordim_confirm-srsrc = resource-rsrc.
          IF lv_state = gc_plhu.
            lv_fcode = fcode_go_to_place_hu.
          ELSEIF lv_state = gc_plmt.
            lv_fcode = fcode_go_to_place_mat.
          ENDIF.
        ENDIF.
      ENDIF.
    ELSEIF lv_step = step_pick_huin   OR
           lv_step = step_source_mtto OR
           lv_step = step_pick_cpmt   OR
           lv_step = step_source_huto OR
           lv_step = step_source_blmt OR
           lv_step = step_source_blcp OR
           lv_step = step_source_blhu OR
           lv_step = step_dest_plmt   OR
           lv_step = step_dest_plhu   OR
           lv_step = step_dest_mphu   OR
           lv_step = step_pick_pilist.
*     In case we are not in initial step.
      IF ordim_confirm-srsrc IS INITIAL.
        IF lv_state = gc_huto.
          lv_fcode = fcode_go_to_pick_huto.
        ELSEIF lv_state = gc_bulk_huto.
          lv_fcode = fcode_go_to_pick_blhu.
        ELSEIF lv_state = gc_mtto.
          lv_fcode = fcode_go_to_pick_mtto.
        ELSEIF lv_state = gc_bulk_mtto.
          lv_fcode = fcode_go_to_pick_blmt.
        ELSEIF lv_state = gc_dd_mtto.
          BREAK-POINT ID /scwm/dd_picking.
          IF ordim_confirm-vlenr IS INITIAL AND
             gv_huobl = wmegc_huobl_obl.
            lv_fcode = fcode_go_to_pick_blmt.
          ELSE.
            lv_fcode = fcode_go_to_pick_mtto.
          ENDIF.
        ENDIF.
      ELSEIF ordim_confirm-srsrc = resource-rsrc.
        IF lv_state = gc_plhu.
          lv_fcode = fcode_go_to_place_hu.
        ELSEIF lv_state = gc_plmt.
          lv_fcode = fcode_go_to_place_mat.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

  IF lv_string = 'PV'.
    IF lv_step = 'PVBSYS'.
*   If initial step of picking transaction
*     Check if all TOs are HU TOs in initial steps
      LOOP AT tt_ordim_confirm INTO ls_ordim_confirm.
        IF ls_ordim_confirm-flghuto <> gc_xfeld AND
           ls_ordim_confirm-srsrc IS INITIAL.
          CLEAR lv_wo_full_hu_tos.
        ENDIF.
      ENDLOOP.

*     Set Fcode Goto Pick HU introduction step.
      IF lv_wo_full_hu_tos IS INITIAL.
        lv_fcode = fcode_go_to_hu_int.
      ELSE.
*     Set fcode for correct source/destination step.
        IF ordim_confirm-srsrc IS INITIAL.
          IF lv_state = gc_huto.
            lv_fcode = fcode_go_to_pick_huto.
          ELSEIF lv_state = gc_bulk_huto.
            lv_fcode = fcode_go_to_pick_blhu.
          ENDIF.
        ELSEIF ordim_confirm-srsrc = resource-rsrc.
          IF lv_state = gc_plhu.
            lv_fcode = fcode_go_to_place_hu.
          ELSEIF lv_state = gc_plmt.
            lv_fcode = fcode_go_to_place_mat.
          ENDIF.
        ENDIF.
      ENDIF.
    ELSEIF lv_step = 'PVHUIN' OR
           lv_step = 'PVMTTO' OR
           lv_step = step_pbv_cpmt OR
           lv_step = step_pbv_blcp OR
           lv_step = 'PVHUTO' OR
           lv_step = 'PVPLMT' OR
           lv_step = 'PVPLHU' OR
           lv_step = 'PVBLMT' OR
           lv_step = 'PVBLHU'.
*     In case we are not in initial step.
      IF ordim_confirm-srsrc IS INITIAL.
        IF lv_state = gc_huto.
          lv_fcode = fcode_go_to_pick_huto.
        ELSEIF lv_state = gc_bulk_huto.
          lv_fcode = fcode_go_to_pick_blhu.
        ELSEIF lv_state = gc_mtto.
          lv_fcode = fcode_go_to_pick_mtto.
        ELSEIF lv_state = gc_bulk_mtto.
          lv_fcode = fcode_go_to_pick_blmt.
        ENDIF.
      ELSEIF ordim_confirm-srsrc = resource-rsrc.
        IF lv_state = gc_plhu.
          lv_fcode = fcode_go_to_place_hu.
        ELSEIF lv_state = gc_plmt.
          lv_fcode = fcode_go_to_place_mat.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

* Destination Bin Blocked Check
  IF ( lv_fcode = fcode_go_to_place_mat OR lv_fcode = fcode_go_to_place_hu ).
    IF ordim_confirm IS NOT INITIAL.
      PERFORM dest_bin_blocked_check
                  CHANGING
                     ordim_confirm
                     cv_fcode.

      IF  cv_fcode = fcode_go_to_bin_den.

*       Get business context depending on Warehouse Process Category
        CALL FUNCTION '/SCWM/T333_READ_SINGLE'
          EXPORTING
            iv_lgnum    = ordim_confirm-lgnum
            iv_procty   = ordim_confirm-procty
          IMPORTING
            es_t333     = ls_t333
          EXCEPTIONS
            not_found   = 1
            wrong_input = 2
            OTHERS      = 3.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

        CASE ls_t333-trart.
          WHEN wmegc_trart_pick. "Picking
            MOVE wmegc_buscon_tpi TO gv_buscon.
          WHEN wmegc_trart_int. "Internal movement
            MOVE wmegc_buscon_tim TO gv_buscon.
          WHEN wmegc_trart_tr.  "Special case Posting change with movement
            MOVE wmegc_buscon_tim TO gv_buscon.
          WHEN OTHERS.
*            MESSAGE e145 WITH ls_t333-trart.
        ENDCASE.


        CLEAR ls_exc.
        MOVE: wmegc_iprcode_chbd TO ls_exc-iprcode,
              ls_t333-nlpla_bl_rf_e TO ls_exc-exccode,
              wmegc_execstep_b4  TO ls_exc-exec_step.
        APPEND ls_exc TO ordim_confirm-exc_tab.
        PERFORM check_double_excep
            USING wmegc_iprcode_chbd
                  ordim_confirm-exc_tab.
        lv_line = /scwm/cl_rf_bll_srvc=>get_line( ).
        IF lv_line = 0.
          READ TABLE tt_ordim_confirm WITH KEY tanum = ordim_confirm-tanum TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            /scwm/cl_rf_bll_srvc=>set_line( sy-tabix ).
            lv_line = /scwm/cl_rf_bll_srvc=>get_line( ).
          ENDIF.
        ENDIF.

        ordim_confirm-srsrc_o = ordim_confirm-srsrc.
        ordim_confirm-drsrc_o = ordim_confirm-drsrc.

        MODIFY tt_ordim_confirm FROM ordim_confirm INDEX lv_line.

        lv_fcode = cv_fcode.
      ENDIF.
    ENDIF.
  ENDIF.

***** Set Fcode  "kontrollo
***  /scwm/cl_rf_bll_srvc=>set_fcode( lv_fcode ).
****  IF lv_fcode = 'GTPLHU'.
****    /scwm/cl_rf_bll_srvc=>clear_fcode_bckg( ).
****    gv_recover = 'X'.
****  ENDIF.

  /scwm/cl_rf_bll_srvc=>set_fcode( lv_fcode ).
  IF lv_fcode = 'GTPLHU' OR lv_fcode = 'GTBSYT'  .
    /scwm/cl_rf_bll_srvc=>clear_fcode_bckg( ).
    gv_recover = 'X'.

    IF gv_who IS INITIAL.
      gv_who = gv_selected_who.
    ENDIF.
    SELECT SINGLE recover_scr
      FROM ztewm_rf_recov
      WHERE lgnum = @resource-lgnum
        AND rsrc  = @resource-rsrc
        AND who   = @gv_who
      INTO @DATA(lv_recover_scr).

    IF sy-subrc = 0 .
      IF lv_recover_scr = 'ZPICK6'.
      " → Screen 6
      /scwm/cl_rf_bll_srvc=>set_fcode( 'GTLP' ).
     ENDIF.

ENDIF.
  ELSEIF lv_fcode = 'BACKF'.
    CALL FUNCTION 'Z_EWM_RF_PICK_LEAVE_TRNS_CHCK'
      CHANGING
        who              = who
        resource         = resource
        ordim_confirm    = ordim_confirm
        tt_ordim_confirm = tt_ordim_confirm.

*    SET PARAMETER ID 'ZPISYS_WORK_WHO' FIELD space.
    EXIT.

  ENDIF.

  CLEAR gv_no_fup_wt.
ENDFUNCTION.
