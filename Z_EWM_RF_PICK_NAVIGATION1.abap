FUNCTION Z_EWM_RF_PICK_NAVIGATION1.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_RESTART_TRANSACTION) TYPE  XFELD
*"     REFERENCE(IV_NEXT) TYPE  XFELD OPTIONAL
*"  CHANGING
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC
*"     REFERENCE(SELECTION) TYPE  /SCWM/S_RF_SELECTION
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT
*"     REFERENCE(WME_VERIF) TYPE  /SCWM/S_WME_VERIF
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS OPTIONAL
*"----------------------------------------------------------------------
* The purpose of this function module is to implement the ENTER
*  functionality. Depending on the actual screen context the ENTER key
*  is treated different.
* Field navigation within the screen is done by the framework.
*  First from verification field to verification field and
*  then from input field to input field.
* This FM is only called if all fields (verification and input) are
*  filled.
* As deafult If all input fields are filled but not all open TO's are
*  confirmed, confirm the actual TO and position to the next open TO.
* If all input fields are filled and all open TO's are confirmed
*  jump to the destination screen (from the source screen) or
*  leave the transaction (from the destinaiton screen).

  DATA: lv_fieldname TYPE fieldname,
        lv_open_to   TYPE i,
        lv_line      TYPE i,
        lv_ltrans    TYPE /scwm/de_ltrans,
        lv_step      TYPE /scwm/de_step,
        lv_fcode     TYPE /scwm/de_fcode,
        lv_shortcut  TYPE /scwm/de_shortcut,
        lv_last_tx   TYPE /scwm/de_ltrans,
        lv_severity  TYPE bapi_mtype,
        lv_split_ok  TYPE char1,
        lv_wcr    TYPE /scwm/de_wcr.

  DATA: lt_ordim_o TYPE /scwm/tt_ordim_o,
        lt_ordim_c TYPE /scwm/tt_ordim_c,
        ls_ordim_o TYPE /scwm/ordim_o,
        ls_who     TYPE /scwm/s_who_int,
        lt_who     TYPE /scwm/tt_who_int,
        lt_to      TYPE /scwm/tt_tanum,
        ls_to      TYPE /scwm/tanum,
        lt_bapiret TYPE bapirettab,
        ls_bapiret TYPE bapiret2.

  DATA: lt_huident        TYPE /scwm/tt_huident,
        lt_huhdr          TYPE /scwm/tt_huhdr_int,
        lv_dest_completed TYPE xfeld,
        ls_huident        TYPE /scwm/s_huident.

  DATA: lv_data_entry              TYPE /scwm/de_data_entry,
        lv_asynchronous_processing TYPE /scwm/de_rf_async.
  DATA: lt_pick_hu_wt              TYPE /scwm/tt_rf_ordim_confirm.

  FIELD-SYMBOLS <huhdr>            TYPE /scwm/s_huhdr_int.
  FIELD-SYMBOLS <s_rf_pick_hus>    TYPE /scwm/s_rf_pick_hus.
  FIELD-SYMBOLS <ls_ordim_confirm> TYPE /scwm/s_rf_ordim_confirm.


  BREAK-POINT ID /scwm/rf_picking.
  IF gv_who IS INITIAL.
    GV_WHO = WHO-WHO.
    ENDIF.

  lv_ltrans = /scwm/cl_rf_bll_srvc=>get_ltrans( ).
  lv_step = /scwm/cl_rf_bll_srvc=>get_step( ).
  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).
  lv_shortcut = /scwm/cl_rf_bll_srvc=>get_shortcut( ).
  lv_line = /scwm/cl_rf_bll_srvc=>get_line( ).

* set local fcode NEXT for navigation.
  IF lv_fcode = fcode_exception AND
     lv_shortcut IS INITIAL.
    lv_fcode = fcode_next.
  ENDIF.

  IF lv_fcode = fcode_backf AND
     lv_shortcut IS INITIAL AND
     iv_next = 'X'.
    lv_fcode = fcode_next.
  ENDIF.

* restart transaction if required.
  IF iv_restart_transaction = /scmb/cl_c=>boole_true.
    /scwm/cl_rf_bll_srvc=>message(
               iv_msg_view = gc_msg_view_scr
               iv_flg_continue_flow = gc_xfeld
               iv_msgid           = gc_picking_msgid
               iv_msgty           = gc_msgty_warning
               iv_msgno           = '023' ).

    /scwm/cl_rf_bll_srvc=>set_prmod(
                             /scwm/cl_rf_bll_srvc=>c_prmod_background ).
    /scwm/cl_rf_bll_srvc=>set_fcode(
                           /scwm/cl_rf_bll_srvc=>c_fcode_compl_ltrans ).

*   Requesting RF Framework to release locks to cover cases where
*   locking of WO was done before calling RF picking transaction.
    /scwm/cl_rf_bll_srvc=>set_flg_dequeue_all( ).

    EXIT.
  ENDIF.

* Processing of ENTER

  "Get kind of warehouse task confirmation. W/ or w/o WAIT
  lv_asynchronous_processing = /scwm/cl_rf_settings=>get_instance( )->is_async_processing( iv_lgnum = ordim_confirm-lgnum iv_queue = ordim_confirm-queue ).

* Check if all TO are confirmed (number of entries in
* tt_ordim_confirm should be 1)
  DESCRIBE TABLE tt_ordim_confirm LINES lv_open_to.

  IF lv_open_to = 0.
    CLEAR lv_shortcut.
  ENDIF..

* If all TOs are confirmed we check if we must quit the transaction
  CHECK lv_shortcut IS INITIAL.

  IF lv_fcode = /scwm/cl_rf_bll_srvc=>c_fcode_enter OR
     lv_fcode = fcode_enterf OR
     lv_fcode = fcode_next OR
     lv_fcode = 'BINDPB'   OR
     lv_fcode = 'DIFFPB'
  .

    CASE lv_open_to.

      WHEN 0.

        IF lv_step = step_source_mtto OR
           lv_step = step_pick_cpmt   OR
           lv_step = step_source_huto OR
           lv_step = step_source_blmt OR
           lv_step = step_source_blcp OR
           lv_step = step_source_blhu OR
           lv_step = step_pbv_cpmt OR
           lv_step = step_pbv_blcp OR
           lv_step = 'PVMTTO' OR
           lv_step = 'PVHUTO' OR
           lv_step = 'PVBLMT' OR
           lv_step = 'PVBLHU'.

*         Step source finished Go to destination
          /scwm/cl_rf_bll_srvc=>set_prmod(
                           /scwm/cl_rf_bll_srvc=>c_prmod_background ).
*         Re-read the WHO. Analyze the first destination TO
*         CALL WO to get WO + TO data
          CALL FUNCTION '/SCWM/RF_PICK_WHO_TO_REFRESH'
            EXPORTING
              iv_lgnum          = resource-lgnum
              iv_who            = gv_who
              iv_next           = iv_next
            IMPORTING
*             new parameter to indicate whether there are WTs from resource to dest bin
              ev_dest_completed = lv_dest_completed
            CHANGING
              ordim_confirm     = ordim_confirm
              tt_ordim_confirm  = tt_ordim_confirm
              who               = who.

          CALL FUNCTION '/SCWM/RF_PICK_SET_STATE'
            CHANGING
              resource      = resource
              ordim_confirm = ordim_confirm.

          CALL FUNCTION '/SCWM/RF_PICK_SET_FCODE'
            CHANGING
              resource         = resource
              ordim_confirm    = ordim_confirm
              tt_ordim_confirm = tt_ordim_confirm.

        ELSEIF lv_step = step_dest_plhu OR
               lv_step = step_dest_plmt OR
               lv_step = step_dest_mphu OR
               lv_step = 'ZPICK6' OR
               lv_step = 'PVPLHU' OR
               lv_step = 'PVPLMT'.

*       Step destination finished go to initial tranasction screen.
          PERFORM pick_return_navigation
            USING  lv_ltrans.

          IF gv_dest_before_quit IS NOT INITIAL.
*           Get WO data
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

*           WO started - split WO?
            IF lt_ordim_o IS NOT INITIAL.
              CALL FUNCTION '/SCWM/RF_PICK_WHO_SPLIT'
                EXPORTING
                  it_ordim_o       = lt_ordim_o
                CHANGING
                  ordim_confirm    = ordim_confirm
                  tt_ordim_confirm = tt_ordim_confirm.

            ENDIF.
          ENDIF.
        ENDIF.

      WHEN OTHERS.

*       Set Presentation mode
        /scwm/cl_rf_bll_srvc=>set_prmod(
                 /scwm/cl_rf_bll_srvc=>c_prmod_foreground ).
*       Re-read the WHO. Analyze the first destination TO
*       CALL WO to get WO + TO data
*       Do not re-read the data if we using a voice device and
*         have entries in tt_ordim_confirm
        lv_data_entry = /scwm/cl_rf_bll_srvc=>get_data_entry( ).

        IF lv_asynchronous_processing = abap_false OR
*          The aync process settings in the customizing does not mean the WT has been processed async mode
*          so we must check how the last WT has been processed
           /scwm/cl_rf_confirm_picking=>get_instance( )->get_last_wt_async_process( ) = abap_false.

          CALL FUNCTION '/SCWM/RF_PICK_WHO_TO_REFRESH'
            EXPORTING
              iv_lgnum          = resource-lgnum
              iv_who            = gv_who
              iv_next           = iv_next
            IMPORTING
*             new parameter to indicate whether there are WTs from resource to dest bin
              ev_dest_completed = lv_dest_completed
            CHANGING
              ordim_confirm     = ordim_confirm
              tt_ordim_confirm  = tt_ordim_confirm
              who               = who.
        ENDIF.

*       In case of pick-by-voice mode if the worker picked partially the WO
*       and want to leave the TX, the system ask do you want to put the picked
*       goods to the destination. In case of yes, we should drive him to the
*       destination screen, but until the WO contains WT from source bin it is
*       not manageable. So we split the WO and let it run.
        IF lv_data_entry = wmegc_data_entry_voice.
          IF lv_fcode = fcode_next AND
             lv_step = 'PVHUIN'.

*           Get WO data
            TRY.
                CALL FUNCTION '/SCWM/WHO_SELECT'
                  EXPORTING
                    iv_to      = gc_xfeld
                    iv_lgnum   = ordim_confirm-lgnum
                    iv_who     = ordim_confirm-who
                  IMPORTING
                    es_who     = ls_who
                    et_ordim_o = lt_ordim_o.
              CATCH /scwm/cx_core.
            ENDTRY.

*           Split and jump to destination makes only sense if we have
*             already a WT from resource to destination.
*           If not, we undo the WO assignment and just end the Tx w/o split.
            CLEAR lv_split_ok.
            LOOP AT lt_ordim_o INTO ls_ordim_o.
              IF ls_ordim_o-srsrc IS INITIAL.
                ls_to = ls_ordim_o-tanum.
                APPEND ls_to TO lt_to.
              ELSE.
                lv_split_ok = 'X'.
              ENDIF.
            ENDLOOP.

            IF lv_split_ok IS NOT INITIAL.
              IF ls_who-wcr IS NOT INITIAL.
                lv_wcr = ls_who-wcr.
              ENDIF.

              CALL FUNCTION '/SCWM/WHO_SPLIT'
                EXPORTING
                  iv_lgnum    = ordim_confirm-lgnum
                  iv_who      = ordim_confirm-who
                  iv_wcr      = lv_wcr
                  iv_commit   = ' '
                  it_to       = lt_to
                IMPORTING
                  ev_severity = lv_severity
                  et_bapiret  = lt_bapiret
                  et_who      = lt_who.

              IF lv_severity CA wmegc_severity_ea.
                ROLLBACK WORK.
                CALL METHOD /scwm/cl_tm=>cleanup( ).

                PERFORM check_bapiret
                  USING lt_bapiret.
              ELSE.
                COMMIT WORK AND WAIT.
                CALL METHOD /scwm/cl_tm=>cleanup( ).
              ENDIF.

              CLEAR ordim_confirm.
              "Delete all not yet picked WT
              DELETE tt_ordim_confirm WHERE srsrc IS INITIAL.
            ENDIF.
          ENDIF.
        ENDIF.

        IF lv_asynchronous_processing = abap_true AND
*          The aync process settings in the customizing does not mean the WT has been processed async mode
*          so we must check how the last WT has been processed
           /scwm/cl_rf_confirm_picking=>get_instance( )->get_last_wt_async_process( ) = abap_true.

          IF lv_fcode = fcode_next.
            "Check if we have an open Pick-HU-WT
            lt_pick_hu_wt = /scwm/cl_rf_confirm_picking=>get_instance( )->get_pick_hu_wt( ).
            IF lt_pick_hu_wt IS NOT INITIAL.
              "Set NEXT flag to avoid CONF_ERROR in PAI of next step
              /scwm/cl_rf_confirm_picking=>get_instance( )->set_next_triggered( iv_next_triggered = abap_true ).
              "Move open Pick-HU WT from buffer to working table and forget the open picks
              tt_ordim_confirm = lt_pick_hu_wt.
              READ TABLE lt_pick_hu_wt INTO ordim_confirm INDEX 1.
            ELSE.
*             We are in NEXT mode and the last WT was async, but previous may be sync.
*             So we might have an open WT to the destination already.
*             Let's refresh the TT_ORDIM* from the WO
              CALL FUNCTION '/SCWM/RF_PICK_WHO_TO_REFRESH'
                EXPORTING
                  iv_lgnum          = resource-lgnum
                  iv_who            = gv_who
                  iv_next           = iv_next
                IMPORTING
*                 new parameter to indicate whether there are WTs from resource to dest bin
                  ev_dest_completed = lv_dest_completed
                CHANGING
                  ordim_confirm     = ordim_confirm
                  tt_ordim_confirm  = tt_ordim_confirm
                  who               = who.

*             Still no open WT? -> Error
              IF tt_ordim_confirm IS INITIAL.
*                MESSAGE e073 WITH ordim_confirm-who.
              ENDIF.
            ENDIF.
          ENDIF.
          IF lv_fcode = fcode_enterf.
            lv_dest_completed = abap_true.
            LOOP AT tt_ordim_confirm ASSIGNING <ls_ordim_confirm>.
              IF <ls_ordim_confirm>-conf_error IS INITIAL.
                IF <ls_ordim_confirm>-srsrc IS NOT INITIAL.
*                 WTs from resource to dest bin exist
                  CLEAR lv_dest_completed.
                ENDIF.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.

*       Check lv_line if out of range. If yes, set lv_line to 1
        IF lv_line > lv_open_to.
          lv_line = 1.
          /scwm/cl_rf_bll_srvc=>set_line( lv_line ).
*       In case of using NEXT in pick-by-voice need to return to
*       initial WT from source bin and instead of process new WT
*       from resource to bin
        ELSEIF lv_line > 1 AND lv_data_entry = wmegc_data_entry_voice.
          READ TABLE tt_ordim_confirm ASSIGNING <ls_ordim_confirm> INDEX lv_line.
          IF <ls_ordim_confirm>-tanum IS INITIAL OR
             <ls_ordim_confirm>-srsrc IS NOT INITIAL.
            READ TABLE tt_ordim_confirm ASSIGNING <ls_ordim_confirm> INDEX 1.
            IF <ls_ordim_confirm>-tanum IS NOT INITIAL.
              lv_line = 1.
              /scwm/cl_rf_bll_srvc=>set_line( lv_line ).
            ENDIF.
          ENDIF.
        ENDIF.

*       Get next TO data.
        READ TABLE tt_ordim_confirm INTO ordim_confirm
             INDEX lv_line.

        CALL FUNCTION '/SCWM/RF_PICK_SET_STATE'
          CHANGING
            resource      = resource
            ordim_confirm = ordim_confirm.

        CALL FUNCTION '/SCWM/RF_PICK_SET_FCODE'
          CHANGING
            resource         = resource
            ordim_confirm    = ordim_confirm
            tt_ordim_confirm = tt_ordim_confirm.

        IF ( lv_step = step_dest_plmt   OR
             lv_step = step_dest_plhu   OR
             lv_step = step_dest_mphu   OR
             lv_step = 'PVPLMT'         OR
             lv_step = 'PVPLHU')  AND
             lv_dest_completed IS NOT INITIAL.
*         for further open WTs return to PICK-HU screen
          /scwm/cl_rf_bll_srvc=>set_fcode( fcode_go_to_hu_int ).

          /scwm/cl_rf_confirm_picking=>get_instance( )->set_next_triggered( iv_next_triggered = abap_false ).

*         delete all Pick_HUs that are already at the destination bin
          ls_huident-lgnum = resource-lgnum.
          LOOP AT t_rf_pick_hus ASSIGNING <s_rf_pick_hus>.
            CLEAR ls_huident.
            MOVE-CORRESPONDING  <s_rf_pick_hus> TO ls_huident.
            IF ls_huident-huident IS NOT INITIAL.
              APPEND ls_huident TO lt_huident.
            ENDIF.
          ENDLOOP.

          IF lt_huident IS NOT INITIAL.
            CALL FUNCTION '/SCWM/HU_GT_FILL'
              EXPORTING
                it_huident = lt_huident
              IMPORTING
                et_huhdr   = lt_huhdr
              EXCEPTIONS
                error      = 1
                OTHERS     = 2.
            IF sy-subrc <> 0.
*                Non-existing HU's. Not interesting to handle here!
            ENDIF.
          ENDIF.

          LOOP AT lt_huhdr ASSIGNING <huhdr> WHERE lgpla IS NOT INITIAL.
            DELETE t_rf_pick_hus WHERE huident EQ <huhdr>-huident.
          ENDLOOP.

          IF lt_huhdr IS INITIAL.
            CLEAR t_rf_pick_hus.
          ENDIF.
        ENDIF.

*       Fill container for application specific verification
        CALL FUNCTION '/SCWM/RF_FILL_WME_VERIF'
          EXPORTING
            iv_lgnum     = ordim_confirm-lgnum
            iv_procty    = ordim_confirm-procty
            iv_trart     = ordim_confirm-trart
            iv_act_type  = ordim_confirm-act_type
            iv_aarea     = ordim_confirm-aarea
          IMPORTING
            es_wme_verif = wme_verif.

        CALL METHOD /scwm/cl_rf_bll_srvc=>set_rebuild_vrf.
    ENDCASE.

  ENDIF.

ENDFUNCTION.
