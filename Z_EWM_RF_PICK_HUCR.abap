FUNCTION z_ewm_rf_pick_hucr .
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(WHO) TYPE  /SCWM/S_WHO_INT
*"     REFERENCE(RESOURCE) TYPE  /SCWM/S_RSRC
*"     REFERENCE(RSRC_TYPE) TYPE  /SCWM/S_TRSRC_TYP
*"     REFERENCE(T_RF_PICK_HUS) TYPE  /SCWM/TT_RF_PICK_HUS
*"     REFERENCE(NESTPT) TYPE  /SCWM/S_RF_NESTED
*"     REFERENCE(ORDIM_CONFIRM) TYPE  /SCWM/S_RF_ORDIM_CONFIRM
*"     REFERENCE(TT_ORDIM_CONFIRM) TYPE  /SCWM/TT_RF_ORDIM_CONFIRM
*"     REFERENCE(S_WHO_SCREEN) TYPE  ZSRF_ZPISYS_WHO_SCREEN OPTIONAL
*"----------------------------------------------------------------------

* generate or retrieve existing pick HU and assign to WHO

* pass user input through parameter NESTPT

  DATA: lv_pmat_guid       TYPE /scwm/de_matid,
        lv_pmat            TYPE /scwm/de_pmat,
        lv_fcode           TYPE /scwm/de_fcode,
        lv_assign_to_who   TYPE xfeld,
        lv_current_line    TYPE /scwm/de_fcode,
        lv_huexist         TYPE boolean,
        lv_get_line        TYPE /scwm/de_fcode,
        lv_get_cursor_line TYPE /scwm/de_fcode,
        lv_tabix           TYPE sy-tabix,
        lv_field(60)       TYPE c,
        lv_added_tabix     TYPE sy-tabix,
        lv_found_hu        TYPE xfeld,
        lv_changed_huhdr   TYPE xfeld,
        lv_huident_verif   TYPE /scwm/de_huident,
        lv_lines           TYPE sy-tabix,
        lv_error_code      LIKE sy-tabix,
        ls_filled_line     TYPE /scwm/s_rf_nested,
        ls_huhdr           TYPE /scwm/s_huhdr_int,
        ls_rf_pick_hus     TYPE /scwm/s_rf_pick_hus,
        ls_current_line    TYPE /scwm/s_rf_pick_hus,
        lt_huhdr           TYPE /scwm/tt_huhdr_int,
        lt_huitm           TYPE /scwm/tt_huitm_int,
        lt_hutree          TYPE /scwm/tt_hutree,
        oref               TYPE REF TO /scwm/cl_wm_packing,
        lo_dd_picking      TYPE REF TO /scwm/cl_dd_picking,
        selection          TYPE /scwm/s_rf_selection,
        rf_pick_hus        TYPE /scwm/s_rf_pick_hus,
        lv_cursor          TYPE i,
        lv_line            TYPE i,
        lv_cursor_line     TYPE i,
        lv_set_okay        TYPE xfeld.

  DATA: lo_badi_pmat TYPE REF TO /scwm/ex_wrkc_ui_pamt_fr_ident,
        lv_pmat_badi TYPE /scwm/de_matid.

  DATA: ls_whohu_maint TYPE /scwm/s_whohu_maint,
        lt_whohu_maint TYPE /scwm/tt_whohu_maint,
        lt_whohu_int   TYPE /scwm/tt_whohu_int,
        lt_whohu       TYPE /scwm/tt_whohu_int.

  DATA lv_packmat_stat      TYPE sy-subrc.

  BREAK-POINT ID /scwm/rf_picking.

*......................................................
* preparations
*......................................................

  CLEAR: lv_assign_to_who.

* Create instance
  CREATE OBJECT oref.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
  lo_dd_picking = /scwm/cl_dd_picking=>get_instance( ).

  CALL METHOD /scwm/cl_rf_bll_srvc=>init_screen_param.

*  REFRESH Ct_who_screen.
*  CLEAR   Cs_who_screen.

  /scwm/cl_rf_bll_srvc=>set_screen_param( 'RSRC_TYPE' ).
* Initialize
  "or CALL METHOD /scwm/cl_wm_packing=>init
*  CALL METHOD oref->init
*    EXPORTING
*      iv_lgnum = who-lgnum
*    EXCEPTIONS
*      OTHERS   = 99.

* Get field
  lv_field = /scwm/cl_rf_bll_srvc=>get_cursor_field( ).
* Get fcode
  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).
  DATA(lv_ltrans) = /scwm/cl_rf_bll_srvc=>get_ltrans( ).
* Get user input
  nestpt-huident_verif = nestpt-rfhu.
  ls_filled_line = nestpt.

  /scwm/cl_rf_bll_srvc=>set_field(
    '/SCWM/S_RF_NESTED-RFHU').

*......................................................
  READ TABLE t_rf_pick_hus
    WITH KEY huident = space
    TRANSPORTING NO FIELDS.
  IF sy-subrc <> 0 AND t_rf_pick_hus IS NOT INITIAL.
    /scwm/cl_rf_bll_srvc=>set_prmod( '1' ).
    /scwm/cl_rf_bll_srvc=>set_fcode( 'PIMTTO' ). " ose fcode_go_to_pick_mtto
    RETURN.
  ENDIF.

*  IF sy-subrc <> 0 AND t_rf_pick_hus IS NOT INITIAL.
*
*    PERFORM save_recov_ctx
*      USING    resource
*               s_who_screen
*               selection
*               who
*               ordim_confirm
*               tt_ordim_confirm
*               t_rf_pick_hus
*               nestpt.
*    ENDIF.
*    /scwm/cl_rf_bll_srvc=>set_prmod( '1' ).
*    /scwm/cl_rf_bll_srvc=>set_fcode( 'PIMTTO' ). " ose fcode_go_to_pick_mtto
*    RETURN.

* Checks of pick hu
*.....................................................

* if not filled HU or filled '$' but filled packaging material
  IF ls_filled_line-huident_verif IS INITIAL OR
     ls_filled_line-huident_verif = '$'.

    CLEAR lv_huident_verif.

*   Check for any existing pick hu with specific packaging material
    PERFORM all_assigned_hus_check
     TABLES t_rf_pick_hus
      USING lv_huident_verif who rsrc_type lv_fcode
   CHANGING lv_found_hu lv_error_code lv_pmat
            lv_pmat_guid lv_tabix ls_filled_line.

    IF NOT lv_found_hu IS INITIAL.
*     Clear input line
      CLEAR nestpt.
      EXIT.
    ENDIF.

*   If filled just pack. material and pressed Enter and not found HU
    IF lv_fcode = /scwm/cl_rf_bll_srvc=>c_fcode_enter.
      EXIT.
    ENDIF.

*   Check packmat is suitbale for a HU type assigned to the resource type
    PERFORM rsrc_hutyp_check
      USING
        who-lgnum
        lv_pmat
        rsrc_type-rsrc_type
      CHANGING
        lv_packmat_stat
    .
    IF lv_packmat_stat  IS NOT INITIAL.
*      MESSAGE e835 WITH lv_pmat resource-rsrc.  jq
    ENDIF.

*DD: check if logpos_ext is provided and matching to HU
    IF abap_false =  lo_dd_picking->validate_pick_hu_at_start(
      EXPORTING
        is_who     = who ).
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
*DD2: check if actual input fits to pack proposal
    IF abap_false = lo_dd_picking->validate_pack_proposal(
        iv_lgnum     = who-lgnum
        iv_who       = who-who
        iv_wcr_type  = who-type
*          iv_huident   =           "Not filled here
        iv_pmat_guid = lv_pmat_guid
           ).
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
*   Create pick hu
    CALL METHOD oref->create_hu_on_resource
      EXPORTING
        iv_pmat     = lv_pmat_guid
*       iv_huident
        iv_resource = resource-rsrc
      RECEIVING
        es_huhdr    = ls_huhdr
      EXCEPTIONS
        error       = 1
        OTHERS      = 2.

    IF sy-subrc NE 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    lv_assign_to_who = 'X'.

    "Filled HU

* Filled HU
  ELSE.
    lv_huident_verif = ls_filled_line-huident_verif.

*   Add leading zeros if needed
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_huident_verif
      IMPORTING
        output = lv_huident_verif.

*   Check specific pick hu with specific packaging material
    PERFORM all_assigned_hus_check
     TABLES t_rf_pick_hus
      USING lv_huident_verif who rsrc_type lv_fcode
   CHANGING lv_found_hu lv_error_code lv_pmat
            lv_pmat_guid lv_tabix ls_filled_line.

    IF NOT lv_found_hu IS INITIAL.
      IF lv_field = gc_filled_rfhu AND
         lv_fcode = /scwm/cl_rf_bll_srvc=>c_fcode_enter AND
         nestpt-huident_verif IS NOT INITIAL.
        lv_huident_verif = nestpt-huident_verif.
        PERFORM set_pointer TABLES t_rf_pick_hus
          USING lv_huident_verif
                lv_set_okay.
      ENDIF.

      PERFORM save_recov_ctx
  USING    resource
           s_who_screen
           selection
           who
           ordim_confirm
           tt_ordim_confirm
           t_rf_pick_hus
           nestpt.

*     Clear input line
      CLEAR nestpt.
      EXIT.
    ENDIF.

    CASE lv_error_code.
      WHEN 8.
*       Pick-HU &1 is already in the destination
*        MESSAGE e067 WITH lv_huident_verif. "JQ
      WHEN 9.
*     "Pick-HU &1 is already assigned to a different packaging material
*        MESSAGE e012 WITH lv_huident_verif.  "JQ
    ENDCASE.

*   Check if hu exists
    CALL METHOD oref->/scwm/if_pack_bas~hu_existence_check
      EXPORTING
        iv_hu    = lv_huident_verif
      RECEIVING
        ev_found = lv_huexist.

*   If hu exists
    IF NOT lv_huexist IS INITIAL.
*     Check if HU is free
      PERFORM hu_free_check TABLES t_rf_pick_hus
        USING oref lv_huident_verif ls_current_line-logpos
              who-lgnum who-who resource
        CHANGING ls_huhdr lv_assign_to_who lv_changed_huhdr.

*     Check if packaging material fits with entered data
      IF lv_pmat_guid IS NOT INITIAL AND
         lv_pmat_guid <> ls_huhdr-pmat_guid.
*        MESSAGE e012 WITH lv_huident_verif. JQ
      ENDIF.
*DD2 : check if logpos_ext is provided and matching to HU
      IF abap_false =  lo_dd_picking->validate_pick_hu_at_start(
        EXPORTING
          iv_huident = lv_huident_verif
          is_who     = who ).
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
*DD2: check if actual input fits to pack proposal
      IF abap_false = lo_dd_picking->validate_pack_proposal(
          iv_lgnum     = who-lgnum
          iv_who       = who-who
          iv_wcr_type  = who-type
          iv_huident   = lv_huident_verif
          iv_pmat      = lv_pmat
          iv_pmat_guid = lv_pmat_guid
             ).
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
***
    ELSE.
*     BAdI for determination of packaging material out of entered HU number
      IF nestpt-pmat IS INITIAL.
        TRY.
            GET BADI lo_badi_pmat
              FILTERS
                lgnum = who-lgnum.
          CATCH cx_badi_not_implemented.                "#EC NO_HANDLER
        ENDTRY.
        IF lo_badi_pmat IS BOUND.
          CALL BADI lo_badi_pmat->get_packmat
            EXPORTING
              iv_lgnum     = who-lgnum
              iv_huident   = lv_huident_verif
            IMPORTING
              ev_pamt_guid = lv_pmat_badi.
        ENDIF.
        IF lv_pmat_badi IS NOT INITIAL.
          lv_pmat_guid = lv_pmat_badi .
        ENDIF.
      ENDIF.
      IF lv_pmat_guid IS INITIAL AND
         lv_field NE gc_filled_pmat.
        /scwm/cl_rf_bll_srvc=>set_field(
          '/SCWM/S_RF_NESTED-PMAT').
        EXIT.
      ENDIF.
*DD2 : check if logpos_ext is provided and matching to HU
      IF abap_false =  lo_dd_picking->validate_pick_hu_at_start(
        EXPORTING
          is_who     = who ).
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
*DD2: check if actual input fits to pack proposal
      IF abap_false = lo_dd_picking->validate_pack_proposal(
          iv_lgnum     = who-lgnum
          iv_who       = who-who
          iv_wcr_type  = who-type
          iv_huident   = lv_huident_verif
          iv_pmat      = lv_pmat
          iv_pmat_guid = lv_pmat_guid
             ).
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.

*     Check if HU is external
      PERFORM hu_external_check
        USING oref lv_huident_verif lv_pmat_guid resource-rsrc
     CHANGING ls_huhdr lv_assign_to_who.

    ENDIF.  "if not lv_huexist is initial

  ENDIF.  "if ls_filled_line-huident_verif is initial or '$'

*......................................................
* Assignment of pick hu to who
*......................................................

  IF lv_assign_to_who IS INITIAL.
    PERFORM save_recov_ctx
  USING    resource
           s_who_screen
           selection
           who
           ordim_confirm
           tt_ordim_confirm
           t_rf_pick_hus
           nestpt.

    EXIT.
  ENDIF.

  CALL FUNCTION '/SCWM/RF_PRINT_GLOBAL_DATA'.

* Save
  CALL METHOD oref->/scwm/if_pack~save
    EXPORTING
      iv_commit = 'X'
      iv_wait   = 'X'
    EXCEPTIONS
      error     = 1
      OTHERS    = 2.
  IF sy-subrc <> 0.
    /scwm/cl_pack_view=>msg_error( ).
  ENDIF.

* Add line with the unassigned HU
  PERFORM add_pickhu_line TABLES t_rf_pick_hus
    USING oref ls_huhdr rsrc_type lv_pmat
          lv_pmat_guid ls_filled_line-logpos lv_tabix
          resource-rsrc
 CHANGING lv_added_tabix.

* The new pick-hus are not assigned to the WO. They are
*   just created on the resoruce and can be used for other WO
*   or on another resource

* In the Pick-Pack-Pass scenario the new pick-hus must be assigned to
*   the top WO. Otherwise the follow-up WO are not informed about
*   the new created pick-HU

  IF who-type = wmegc_wcr_ppp_sd OR
     who-type = wmegc_wcr_ppp_ud.
    LOOP AT t_rf_pick_hus INTO ls_rf_pick_hus.
      MOVE-CORRESPONDING ls_rf_pick_hus TO ls_whohu_maint.

      IF sy-tabix EQ lv_added_tabix.
        ls_whohu_maint-huident = ls_huhdr-huident.
        ls_whohu_maint-updkz = 'I'.
        CLEAR ls_rf_pick_hus.
        ls_rf_pick_hus-huident = ls_huhdr-huident.
        APPEND ls_whohu_maint TO lt_whohu_maint.
      ENDIF.
    ENDLOOP.

*    Assign lt_whohu to top WHO
    CALL FUNCTION '/SCWM/WHO_WHOHU_MAINT'
      EXPORTING
        iv_lgnum = who-lgnum
        iv_who   = who-topwhoid
        it_whohu = lt_whohu_maint
      IMPORTING
        et_whohu = lt_whohu_int.

*    Save
    CALL METHOD oref->/scwm/if_pack~save
      EXPORTING
        iv_commit = 'X'
        iv_wait   = 'X'
      EXCEPTIONS
        error     = 1
        OTHERS    = 2.
    IF sy-subrc <> 0.
      /scwm/cl_pack_view=>msg_error( ).
    ENDIF.

    COMMIT WORK AND WAIT.
    CALL METHOD /scwm/cl_tm=>cleanup( ).
  ELSE.
*   update the WHOHU table with the HUIDENT.
    TRY.
        CALL FUNCTION '/SCWM/WHO_SELECT'
          EXPORTING
            iv_lgnum = ordim_confirm-lgnum
            iv_who   = ordim_confirm-who
          IMPORTING
            et_whohu = lt_whohu.
      CATCH /scwm/cx_core.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDTRY.

    DATA: ls_trsrc_typ    TYPE /scwm/trsrc_typ.
    DATA: lv_postn_mngmnt TYPE /scwm/de_postn.

*   Get resource types data
    CALL FUNCTION '/SCWM/RSRC_TRSRC_TYP_READ'
      EXPORTING
        iv_lgnum     = resource-lgnum
        iv_rsrc_type = resource-rsrc_type
      IMPORTING
        es_trsrc_typ = ls_trsrc_typ
      EXCEPTIONS
        not_found    = 1
        OTHERS       = 2.

    IF sy-subrc IS INITIAL.
      lv_postn_mngmnt = ls_trsrc_typ-postn_mngmnt.
    ENDIF.

*   do not create WHOHU entry for such a WHO where was no
*   pickhu proposal
    IF ( lt_whohu IS NOT INITIAL AND
       lv_added_tabix <= lines( lt_whohu ) )
     OR ( lv_postn_mngmnt = gc_auto_postn_mng AND lv_fcode = fcode_hucr ).
      LOOP AT t_rf_pick_hus INTO ls_rf_pick_hus.
        MOVE-CORRESPONDING ls_rf_pick_hus TO ls_whohu_maint.

        IF sy-tabix EQ lv_added_tabix.
          ls_whohu_maint-huident = ls_huhdr-huident.
          ls_whohu_maint-updkz = 'U'.
          CLEAR ls_rf_pick_hus.
          ls_rf_pick_hus-huident = ls_huhdr-huident.
          APPEND ls_whohu_maint TO lt_whohu_maint.
        ENDIF.
      ENDLOOP.

*     Assign lt_whohu to WHO
      IF lt_whohu_maint IS NOT INITIAL.
        CALL FUNCTION '/SCWM/WHO_WHOHU_MAINT'
          EXPORTING
            iv_lgnum = who-lgnum
            iv_who   = who-who
            it_whohu = lt_whohu_maint
          IMPORTING
            et_whohu = lt_whohu_int.

**       Save
        CALL METHOD oref->/scwm/if_pack~save
          EXPORTING
            iv_commit = 'X'
            iv_wait   = 'X'
          EXCEPTIONS
            error     = 1
            OTHERS    = 2.
        IF sy-subrc <> 0.
          /scwm/cl_pack_view=>msg_error( ).
        ENDIF.

        COMMIT WORK AND WAIT.
        CALL METHOD /scwm/cl_tm=>cleanup( ).
      ENDIF.
    ENDIF.
  ENDIF.

* Update packaging material list
  PERFORM update_material_list
    TABLES t_rf_pick_hus
     USING resource who ls_huhdr lv_pmat_guid.

* Move to added line
  PERFORM set_cursor_line TABLES t_rf_pick_hus
    USING ls_rf_pick_hus rsrc_type lv_added_tabix ' '.

* Count internal table lines
  DESCRIBE TABLE t_rf_pick_hus LINES lv_lines.
  ordim_confirm-sumphu = lv_lines.
  IF ordim_confirm-sumphu IS NOT INITIAL.
    gv_hunr = ordim_confirm-sumphu.
  ENDIF.
* Clear input line, if there is no more proposed pickHU with empty HU number
  READ TABLE t_rf_pick_hus WITH KEY huident = ''
    INTO ls_rf_pick_hus.
  IF sy-subrc IS INITIAL.
    CLEAR nestpt.
    MOVE-CORRESPONDING ls_rf_pick_hus TO nestpt.
  ELSE.
    CLEAR nestpt.
  ENDIF.

* Re-read and lock the WO again
  TRY.
      CALL FUNCTION '/SCWM/WHO_SELECT'
        EXPORTING
          iv_lgnum    = ordim_confirm-lgnum
          iv_who      = ordim_confirm-who
          iv_lock_who = 'X'.
    CATCH /scwm/cx_core.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDTRY.
  /scwm/cl_rf_bll_srvc=>set_line( 1 ).
  PERFORM save_recov_ctx
  USING    resource
           s_who_screen
           selection
           who
           ordim_confirm
           tt_ordim_confirm
           t_rf_pick_hus
           nestpt.


ENDFUNCTION.



*......................................................................
* form RSRC_HUTYP_CHECK
*.....................................................................
*
*   check HU type of the resource type assigned to the resource
*   against HU type of the packmat
*   Algortihm:
*   Find all HU type group for one resource type
*   Find HU type group of the packmat
*   Look for this HU type group of the resource type
*.....................................................................

FORM rsrc_hutyp_check
  USING
    iv_lgnum          TYPE /scwm/lgnum
    iv_pmat           TYPE /scwm/de_pmat
    iv_rsrc_type      TYPE /scwm/de_rsrc_type
  CHANGING
    cv_packmat_stat   TYPE  sy-subrc
.

  DATA lt_hu_grp_pr     TYPE        /scwm/tt_hu_grp_pr.
  DATA lo_stock_fields  TYPE REF TO /scwm/cl_ui_stock_fields.
  DATA lv_pmat_guid     TYPE        /scwm/de_matid.
  DATA ls_mat_pack      TYPE        /scwm/s_material_pack.
  DATA ls_t307          TYPE        /scwm/t307.

  CLEAR cv_packmat_stat.
  CALL FUNCTION '/SCWM/RSRC_HU_GRP_PR_GET'
    EXPORTING
      iv_lgnum     = iv_lgnum
*     IV_WILDCARD  =
*   IMPORTING
*     ET_HU_GRP_PR_WC       =
    CHANGING
      ct_hu_grp_pr = lt_hu_grp_pr.

  DELETE lt_hu_grp_pr WHERE rsrc_type <> iv_rsrc_type.
  IF lines( lt_hu_grp_pr ) IS INITIAL.
*   HU type group is not assigned to the resource -> NO restriction for packmat
    RETURN.
  ENDIF.

  IF iv_pmat IS NOT INITIAL.
*   Get guid of packaging material
    IF lo_stock_fields IS NOT BOUND.
      CREATE OBJECT lo_stock_fields.
    ENDIF.
    CALL METHOD lo_stock_fields->get_matid_by_no
      EXPORTING
        iv_matnr = iv_pmat
      RECEIVING
        ev_matid = lv_pmat_guid.
    IF lv_pmat_guid IS INITIAL.
      "Packaging material &1 is not defined
*      MESSAGE e061 WITH iv_pmat.  jq
    ENDIF.
  ENDIF.

  TRY.
      CALL FUNCTION '/SCWM/MATERIAL_READ_SINGLE'
        EXPORTING
          iv_matid    = lv_pmat_guid
*         IV_LANGU    = SY-LANGU
*         IV_ENTITLED =
*         IV_APPLIC   =
          iv_lgnum    = iv_lgnum
        IMPORTING
          es_mat_pack = ls_mat_pack.
    CATCH /scwm/cx_md_interface
          /scwm/cx_md_material_exist
          /scwm/cx_md_mat_lgnum_exist
          /scwm/cx_md_lgnum_locid
          /scwm/cx_md.
      RETURN.
  ENDTRY.
* Read HU types of the HU type group
  CALL FUNCTION '/SCWM/T307_READ_SINGLE'
    EXPORTING
      iv_lgnum    = iv_lgnum
      iv_letyp    = ls_mat_pack-hutyp
    IMPORTING
      es_t307     = ls_t307
    EXCEPTIONS
      not_found   = 1
      wrong_input = 2
      OTHERS      = 3.
  IF sy-subrc <> 0.
* MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

  DELETE lt_hu_grp_pr WHERE hut_grp <> ls_t307-hutypgrp.
  IF lines( lt_hu_grp_pr ) IS INITIAL.
    cv_packmat_stat = 1. "Not suitable packmat
  ENDIF.
ENDFORM. "rsrc_hutyp_check
*......................................................................
* form all_assigned_hus_check
*.....................................................................
*
* check all assigned hus:
* - any hu      with requested packaging material
* - specific hu with (or without) requested packaging material
*
*.....................................................................

FORM all_assigned_hus_check
  TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
   USING pv_filled_huident TYPE /scwm/de_huident
         ps_who TYPE /scwm/s_who_int
         ps_rsrc_type TYPE /scwm/s_trsrc_typ
         pv_fcode TYPE /scwm/de_fcode
CHANGING pv_found_hu TYPE xfeld
         pv_error_code LIKE sy-tabix
         pv_pmat TYPE /scwm/de_pmat
         pv_pmat_guid TYPE /scwm/de_matid
         pv_tabix TYPE sy-tabix
         ps_filled_line TYPE /scwm/s_rf_nested.

  DATA: lv_pmat TYPE /scwm/de_pmat.
  DATA: lv_pmat_guid TYPE /scwm/de_matid.
  DATA: lv_current_pmat_guid TYPE /scwm/de_matid.
  DATA: lv_logpos TYPE /scwm/de_logpos.
  DATA: lv_current_huident TYPE /scwm/de_huident.
  DATA: lv_current_dstgrp TYPE /scwm/de_dstgrp.
  DATA: lv_huident_verif TYPE /scwm/de_huident_verif.
  DATA: lv_tabix LIKE sy-tabix.
  DATA: lv_found_record TYPE xfeld.
  DATA: ls_huhdr TYPE /scwm/s_huhdr_int.
  DATA: ls_filled_line TYPE /scwm/s_rf_nested.
  DATA: ls_rf_pick_hus TYPE /scwm/s_rf_pick_hus.
  DATA: ls_data TYPE /scmb/mdl_matnr_str.
  DATA: lv_empty_huident TYPE /scwm/de_huident VALUE IS INITIAL.
  DATA: ls_mat_global TYPE /scwm/s_material_global.

  DATA: lo_stock_fields  TYPE REF TO /scwm/cl_ui_stock_fields.

  CLEAR: pv_found_hu, pv_error_code, lv_found_record.
  ps_filled_line-huident_verif = pv_filled_huident. "with leading zeros
  ls_filled_line = ps_filled_line.
  lv_pmat = ls_filled_line-pmat.

  IF ps_who-type = wmegc_wcr_dd . "Distribution Device: check against proposed packmat
    BREAK-POINT ID /scwm/dd_picking.
    IF lv_pmat IS INITIAL.  "User only entered existing HU w/o entering a packaging material
      DATA lo_dd_picking       TYPE REF TO /scwm/cl_dd_picking.
      lo_dd_picking = /scwm/cl_dd_picking=>get_instance( ).
      DATA(lv_pmat_check) =  lo_dd_picking->read_packmat_of_hu(
        EXPORTING
          iv_huident     = pv_filled_huident ).
      "User enters an existing HU but packaging material is empty on the screen
      "  -> we have to set LV_PMAT otherwise WHOHU gets a new entry instead of updating.
      lv_pmat = lv_pmat_check.
    ELSE.
      lv_pmat_check = lv_pmat.
    ENDIF.
    IF lines( pt_rf_pick_hus ) > 0.
      READ TABLE pt_rf_pick_hus INTO ls_rf_pick_hus WITH KEY pmat = lv_pmat_check.
      IF sy-subrc IS NOT INITIAL.
        READ TABLE pt_rf_pick_hus INTO ls_rf_pick_hus WITH KEY huident = lv_empty_huident.
        IF sy-subrc <> 0.
          READ TABLE pt_rf_pick_hus INTO ls_rf_pick_hus INDEX 1.
        ENDIF.
*        message e328 with lv_pmat ls_rf_pick_hus-pmat.   jq
      ENDIF.
    ENDIF.
  ENDIF.

* If filled packaging material
  IF NOT lv_pmat IS INITIAL.
*   Get guid of packaging material
    IF lo_stock_fields IS NOT BOUND.
      CREATE OBJECT lo_stock_fields.
    ENDIF.
    CALL METHOD lo_stock_fields->get_matid_by_no
      EXPORTING
        iv_matnr = lv_pmat
      RECEIVING
        ev_matid = lv_pmat_guid.
    IF lv_pmat_guid IS INITIAL.
      "Packaging material &1 is not defined
*      MESSAGE e061 WITH lv_pmat.   jq
    ENDIF.
  ENDIF.

*.................................................................

* if filled pick HU
  IF NOT pv_filled_huident IS INITIAL.
*   Search for record with specific huident and pack. material
    IF NOT lv_pmat_guid IS INITIAL.
      READ TABLE pt_rf_pick_hus INTO ls_rf_pick_hus
        WITH KEY huident = pv_filled_huident
                 pmat_guid = lv_pmat_guid.
*   Search for record with specific huident
    ELSE.
      READ TABLE pt_rf_pick_hus INTO ls_rf_pick_hus
        WITH KEY huident = pv_filled_huident.
    ENDIF.
*   If found record
    IF sy-subrc = 0.
      pv_tabix = sy-tabix.
      lv_pmat_guid = ls_rf_pick_hus-pmat_guid.
      pv_found_hu = gc_xfeld.
      IF lv_pmat IS INITIAL.
*       Get packaging material from guid
*        CALL FUNCTION 'CONVERSION_EXIT_MDLPD_OUTPUT'
*          EXPORTING
*            input  = lv_pmat_guid
*          IMPORTING
*            output = lv_pmat.
        TRY.
            CALL FUNCTION '/SCWM/MATERIAL_READ_SINGLE'
              EXPORTING
                iv_matid      = lv_pmat_guid
              IMPORTING
                es_mat_global = ls_mat_global.
          CATCH /scwm/cx_md.
          CATCH /scwm/cx_md_api_faulty_call. " faulty call of md api
          CATCH /scwm/cx_md_exception.       " exception class for md read logic
            CLEAR ls_mat_global.
        ENDTRY.
        lv_pmat = ls_mat_global-matnr.

      ENDIF.
*     Check that pick-hu is not already in destination (by previous TO)
      PERFORM check_pickhu_dest USING ps_who ls_rf_pick_hus-huident
        CHANGING pv_found_hu lv_found_record pv_error_code.
    ELSE.
      IF NOT lv_pmat_guid IS INITIAL.
*       Check if for entry with the same pack. mat. and with initial HU
        READ TABLE pt_rf_pick_hus INTO ls_rf_pick_hus
          WITH KEY huident = lv_empty_huident
                   pmat_guid = lv_pmat_guid.
        pv_tabix = sy-tabix.
        lv_found_record = gc_xfeld.
      ENDIF.
    ENDIF.
* Not filled pick HU
  ELSE.
*   Search for first record with specific packaging material
    LOOP AT pt_rf_pick_hus INTO ls_rf_pick_hus
      WHERE pmat_guid = lv_pmat_guid.
      pv_tabix = sy-tabix.
*     For HU creation search for record with pack. material and w/o hu
      IF pv_fcode = fcode_hucr AND
        NOT ls_rf_pick_hus-huident IS INITIAL.
        CLEAR pv_tabix.
        CONTINUE.
      ENDIF.
      lv_found_record = gc_xfeld.
      IF NOT ls_rf_pick_hus-huident IS INITIAL.
        pv_found_hu = gc_xfeld.
*       Check pick-hu is not already in destination (by previous TO)
        PERFORM check_pickhu_dest USING ps_who ls_rf_pick_hus-huident
          CHANGING pv_found_hu lv_found_record pv_error_code.
      ENDIF.
*     Search for another pick hu with this material
      IF lv_found_record IS INITIAL.
        CONTINUE.
      ENDIF.
      EXIT.
    ENDLOOP.
  ENDIF.

*.................................................................

* If found HU or just located first packaging material in internal table
  IF pv_found_hu = 'X' OR lv_found_record ='X'.

*   Modify hu verification in found line
    ls_rf_pick_hus-huident_verif = ls_rf_pick_hus-huident.
    MODIFY pt_rf_pick_hus FROM ls_rf_pick_hus TRANSPORTING huident_verif
      WHERE huident = ls_rf_pick_hus-huident.

*   Set cursor line
    PERFORM set_cursor_line TABLES pt_rf_pick_hus
      USING ls_rf_pick_hus ps_rsrc_type pv_tabix 'X'.

* Not found HU/record
  ELSE.

    IF NOT pv_error_code IS INITIAL.
      EXIT.
    ENDIF.

*   Check hu assigned to different packaging material(than current line)
    READ TABLE pt_rf_pick_hus WITH KEY huident = pv_filled_huident.
    IF sy-subrc = 0.
      pv_error_code = 9.
    ENDIF.

  ENDIF.

  pv_pmat = lv_pmat.
  pv_pmat_guid = lv_pmat_guid.

ENDFORM.  "all_assigned_hus_check



*...........................................................
* form hu_free_check
*...........................................................
*
* check if hu is free
* and mark flag for its assignment to warehouse order
*...........................................................

FORM hu_free_check TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
                    USING po_oref TYPE REF TO /scwm/cl_wm_packing
                          pv_huident TYPE /scwm/de_huident
                          pv_logpos TYPE /scwm/de_logpos
                          pv_lgnum  TYPE /scwm/lgnum
                          pv_who    TYPE /scwm/de_who
                          ps_rsrc   TYPE /scwm/s_rsrc
                 CHANGING ps_huhdr TYPE /scwm/s_huhdr_int
                          pv_assign_to_who TYPE xfeld
                          pv_changed_huhdr TYPE xfeld.

  DATA: ls_whohu   TYPE /scwm/whohu,
        ls_ordim_o TYPE /scwm/ordim_o,
        lt_ordim_o TYPE /scwm/tt_ordim_o.

  DATA: lv_error TYPE xfeld,
        lv_msg   TYPE string.
  DATA: lo_huid_service TYPE REF TO /scwm/if_af_huid_service.

  CLEAR: ps_huhdr, pv_assign_to_who.

  "After this check the HU is locked, even if it can't be used by this user.
  "  This might cause issues for another user who uses this HU now -> Dequeue HU in case of error
  CALL METHOD po_oref->is_hu_available
    EXPORTING
      iv_huident    = pv_huident
      iv_lock       = gc_xfeld
    IMPORTING
      es_huhdr      = ps_huhdr
    EXCEPTIONS
      error         = 1
      not_available = 2
      OTHERS        = 3.

* If HU is available or
*    HU is already on resource
  IF ( ( sy-subrc = 0 ) OR
       ( sy-subrc = 2 AND
         ps_huhdr-rsrc = ps_rsrc-rsrc AND
         ps_huhdr-rsrc IS NOT INITIAL ) ).
*   Check on /SCWM/WHOHU is HU is already assigned to another WO
    CALL FUNCTION '/SCWM/WHOHU_SELECT'
      EXPORTING
        iv_lgnum   = pv_lgnum
*       IV_WHOID   =
*       IV_HUKNG   =
*       IV_PMAT    =
        iv_huident = pv_huident
      IMPORTING
        es_whohu   = ls_whohu
      EXCEPTIONS
        not_found  = 1        "That's okay
        OTHERS     = 2.
    IF sy-subrc > 1.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_msg.
      lv_error = abap_true.
    ENDIF.
    IF sy-subrc = 0 AND ls_whohu-who <> pv_who AND lv_error IS INITIAL.
*     Pick-Hu already assigned to another WO
*      MESSAGE e130 WITH ls_whohu-who INTO lv_msg.   jq
      lv_error = abap_true.
    ENDIF.
*   Check if already open WT for this HU exists for another WO
    IF lv_error IS INITIAL.
      CALL FUNCTION '/SCWM/TO_READ_SRC'
        EXPORTING
          iv_lgnum     = pv_lgnum
          iv_huident   = pv_huident
        IMPORTING
          et_ordim_o   = lt_ordim_o
        EXCEPTIONS
          wrong_input  = 1
          not_found    = 2
          foreign_lock = 3
          OTHERS       = 4.
      IF sy-subrc <> 0 AND sy-subrc <> 2.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_msg.
        lv_error = abap_true.
      ENDIF.

      LOOP AT lt_ordim_o INTO ls_ordim_o.
        IF ls_ordim_o-who <> pv_who AND
           ls_ordim_o-who IS NOT INITIAL.
*       Pick-Hu already assigned to another WO
*        MESSAGE e130 WITH ls_ordim_o-who INTO lv_msg. jq
          lv_error = abap_true.
        ENDIF.
      ENDLOOP.

      IF lv_error IS INITIAL.
        pv_assign_to_who = gc_xfeld.
      ENDIF.
    ENDIF.
  ELSE.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_msg.
    lv_error = abap_true.
  ENDIF.

  IF lv_error IS NOT INITIAL.
    "Dequeue HU
    lo_huid_service ?= /scdl/cl_af_management=>get_instance( )->get_service(  /scwm/if_af_huid_service=>sc_me_as_service ).
    TRY.
        lo_huid_service->dequeue_hu(
          EXPORTING
            iv_lgnum   =  pv_lgnum
            iv_huident =  pv_huident

        ).
      CATCH /scwm/cx_huid_service. " HUID Service Exception
        lv_error = abap_true.
    ENDTRY.

    "Raise message
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.  "hu_free_check



*...................................................................
* form hu_external_check
*...................................................................
*
* check if hu is from external number range (by trying to create it)
* create it in this case
* and mark flag for its assignment to warehouse order
*...................................................................

FORM hu_external_check
   USING po_oref TYPE REF TO /scwm/cl_wm_packing
         pv_huident TYPE /scwm/de_huident
         pv_mat_guid TYPE /scwm/de_matid
         pv_rsrc TYPE /scwm/de_rsrc
CHANGING ps_huhdr TYPE /scwm/s_huhdr_int
         pv_assign_to_who TYPE xfeld.


  CLEAR: ps_huhdr, pv_assign_to_who.

* Create pick hu
  CALL METHOD po_oref->create_hu_on_resource
    EXPORTING
      iv_pmat     = pv_mat_guid
      iv_huident  = pv_huident
      iv_resource = pv_rsrc
    RECEIVING
      es_huhdr    = ps_huhdr
    EXCEPTIONS
      error       = 1
      OTHERS      = 2.

  IF sy-subrc = 0.
    pv_assign_to_who = gc_xfeld.
  ELSE.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.  "hu_external_check



*......................................................................
* form check_pickhu_dest
*.....................................................................
*
* check that pick-hu is not already in destination (by previous TO)
*.....................................................................

FORM check_pickhu_dest USING ps_who TYPE /scwm/s_who_int
                             pv_huident TYPE /scwm/de_huident
                    CHANGING pv_found_hu TYPE xfeld
                             pv_found_record TYPE xfeld
                             pv_error_code LIKE sy-tabix.

  DATA: ls_ordim_c TYPE /scwm/ordim_c.
  DATA: lt_ordim_c TYPE /scwm/tt_ordim_c.

  IF pv_found_hu NE gc_xfeld.
    EXIT.
  ENDIF.

  CALL FUNCTION '/SCWM/TO_READ_WHO'
    EXPORTING
      iv_lgnum      = ps_who-lgnum
      iv_who        = ps_who-who
      iv_flglock    = space
    IMPORTING
      et_ordim_c    = lt_ordim_c
    EXCEPTIONS
      error_message = 99
      OTHERS        = 1.

  LOOP AT lt_ordim_c INTO ls_ordim_c.
*   If this is not a TO from source to pick-hu on the resource
*   but a TO from resource to pick-hu in destination bin
    IF ls_ordim_c-drsrc EQ space AND
      ls_ordim_c-nlenr = pv_huident.
      CLEAR: pv_found_record, pv_found_hu.
      pv_error_code = 8.
      EXIT.                                             "#EC CI_NOORDER
    ENDIF.
  ENDLOOP.

ENDFORM.  "check_pickhu_dest



*......................................................................
* form add_pickhu_line
*.....................................................................
*
* add a line to internal table for a non-assigned pick-HU
*.....................................................................

FORM add_pickhu_line TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
                      USING po_oref TYPE REF TO /scwm/cl_wm_packing
                            ps_huhdr TYPE /scwm/s_huhdr_int
                            ps_rsrc_type TYPE /scwm/s_trsrc_typ
                            pv_pmat TYPE /scwm/de_pmat
                            pv_pmat_guid TYPE /scwm/de_matid
                            pv_logpos TYPE /scwm/de_logpos
                            pv_tabix TYPE sy-tabix
                            pv_rsrc TYPE /scwm/de_rsrc
                   CHANGING pv_added_tabix TYPE sy-tabix.


  DATA: lv_lines TYPE sy-tabix.
  DATA: lv_new_line TYPE sy-tabix.
  DATA: lv_changed_huhdr TYPE xfeld.
  DATA: ls_rf_pick_hus TYPE /scwm/s_rf_pick_hus.
  DATA: ls_exist_line TYPE /scwm/s_rf_pick_hus.
  DATA: ls_huhdr TYPE /scwm/s_huhdr_int.
  DATA: ls_filled_line TYPE /scwm/s_rf_pick_hus.
  DATA: lv_numc2  TYPE numc2.

* Count internal table lines
  DESCRIBE TABLE pt_rf_pick_hus LINES lv_lines.
  lv_new_line = lv_lines + 1.

* If found a record with the requested pack. material
  IF NOT pv_tabix IS INITIAL.
    READ TABLE pt_rf_pick_hus INDEX pv_tabix INTO ls_exist_line.
    pv_added_tabix = pv_tabix.
  ELSE.
    pv_added_tabix = lv_lines + 1.
  ENDIF.

* Prepare new pick HU line
  CLEAR ls_rf_pick_hus.
  IF pv_pmat IS NOT INITIAL.
    ls_rf_pick_hus-pmat = pv_pmat.
    ls_rf_pick_hus-pmat_guid = pv_pmat_guid.
  ELSE.
    ls_rf_pick_hus-pmat = ps_huhdr-pmat.
    ls_rf_pick_hus-pmat_guid = ps_huhdr-pmat_guid.
  ENDIF.
  ls_rf_pick_hus-logpos = ls_exist_line-logpos.
  ls_rf_pick_hus-hukng  = ls_exist_line-hukng.
  ls_rf_pick_hus-huident = ps_huhdr-huident.
* Identify new line
  ls_rf_pick_hus-huident_verif = ps_huhdr-huident.
  ls_rf_pick_hus-dstgrp = ps_huhdr-dstgrp.
  IF ps_rsrc_type-postn_mngmnt = gc_auto_postn_mng AND
    ls_exist_line-logpos IS INITIAL.
    IF ps_huhdr-logpos IS NOT INITIAL AND ps_huhdr-rsrc = pv_rsrc.
      READ TABLE pt_rf_pick_hus TRANSPORTING NO FIELDS
        WITH KEY logpos = ps_huhdr-logpos.
      IF sy-subrc IS NOT INITIAL.
        ls_rf_pick_hus-logpos = ps_huhdr-logpos.
      ENDIF.
    ENDIF.
*   For automatic position mgmt have to check the gaps
*   between occupied positions. The position should be
*   unique so check all positions and use the first empty
    lv_numc2 = 1.
    WHILE lv_numc2 <= lv_new_line AND
      ls_rf_pick_hus-logpos IS INITIAL.
      READ TABLE pt_rf_pick_hus TRANSPORTING NO FIELDS
        WITH KEY logpos = lv_numc2.
      IF sy-subrc IS NOT INITIAL.
        ls_rf_pick_hus-logpos = lv_numc2.
      ENDIF.
      lv_numc2 = lv_numc2 + 1.
    ENDWHILE.
*   Update logical position in HU header
    PERFORM update_logpos_huhdr TABLES pt_rf_pick_hus
      USING po_oref ps_huhdr-huident ls_rf_pick_hus-logpos
            pv_added_tabix
   CHANGING ls_huhdr lv_changed_huhdr.
*  Update the logical position to the HUHDR DB table.
    IF NOT lv_changed_huhdr IS INITIAL.
*       Save
      CALL METHOD po_oref->/scwm/if_pack~save
        EXPORTING
          iv_commit = 'X'
          iv_wait   = 'X'
        EXCEPTIONS
          error     = 1
          OTHERS    = 2.
      IF sy-subrc <> 0.
        /scwm/cl_pack_view=>msg_error( ).
      ENDIF.
    ENDIF.
  ELSEIF ps_rsrc_type-postn_mngmnt = gc_manual_postn_mng.
    ls_rf_pick_hus-logpos = pv_logpos.
    IF ls_rf_pick_hus-logpos IS INITIAL AND ps_huhdr-logpos IS NOT INITIAL
      AND ps_huhdr-rsrc = pv_rsrc.
      READ TABLE pt_rf_pick_hus TRANSPORTING NO FIELDS
        WITH KEY logpos = ps_huhdr-logpos.
      IF sy-subrc IS NOT INITIAL.
        ls_rf_pick_hus-logpos = ps_huhdr-logpos.
      ENDIF.
    ENDIF.
*  If automatic position mgmt and /scwm/whohu entries present for HU creation.
  ELSEIF ps_rsrc_type-postn_mngmnt = gc_auto_postn_mng AND
   ls_exist_line-logpos IS NOT INITIAL AND ls_huhdr-logpos NE ls_exist_line-logpos.
    PERFORM update_logpos_huhdr TABLES pt_rf_pick_hus
      USING po_oref ps_huhdr-huident ls_rf_pick_hus-logpos
            pv_added_tabix
    CHANGING ls_huhdr lv_changed_huhdr.
**  Save
    CALL METHOD po_oref->/scwm/if_pack~save
      EXPORTING
        iv_commit = 'X'
        iv_wait   = 'X'
      EXCEPTIONS
        error     = 1
        OTHERS    = 2.
    IF sy-subrc <> 0.
      /scwm/cl_pack_view=>msg_error( ).
    ENDIF.
  ENDIF.

* If found a record with the requested pack. material
  IF NOT pv_tabix IS INITIAL.
*   Modify pick HU line
    MODIFY pt_rf_pick_hus FROM ls_rf_pick_hus INDEX pv_added_tabix.
  ELSE.
*   Insert new pick HU line
    INSERT ls_rf_pick_hus INTO pt_rf_pick_hus INDEX pv_added_tabix.
  ENDIF.

ENDFORM.  "add_pickhu_line



*......................................................................
* form update_logpos_huhdr
*.....................................................................
*
*   update logical position in HU header
*.....................................................................

FORM update_logpos_huhdr TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
                          USING po_oref TYPE REF TO /scwm/cl_wm_packing
                                pv_huident TYPE /scwm/de_huident
                                pv_logpos TYPE /scwm/de_logpos
                                pv_tabix TYPE sy-tabix
                       CHANGING ps_huhdr TYPE /scwm/s_huhdr_int
                                pv_changed_huhdr TYPE xfeld.

  DATA: ls_rf_pick_hus TYPE /scwm/s_rf_pick_hus.


  IF pv_huident IS INITIAL.
    EXIT.
  ENDIF.

  IF NOT pv_logpos IS INITIAL.
*   Check if logical position already exists
    LOOP AT pt_rf_pick_hus INTO ls_rf_pick_hus
         WHERE logpos = pv_logpos.
      IF ls_rf_pick_hus-huident NE pv_huident.
        /scwm/cl_rf_bll_srvc=>set_field(
          '/SCWM/S_RF_PICK_HUS-LOGPOS').
*       Logical position &1 already exists
*        MESSAGE e068 WITH pv_logpos.   jq
      ENDIF.
    ENDLOOP.
  ENDIF.

  IF ps_huhdr IS INITIAL.
*   Get HU header data
    CALL METHOD po_oref->/scwm/if_pack_bas~get_hu(
      EXPORTING
        iv_huident = pv_huident
      IMPORTING
        es_huhdr   = ps_huhdr
      EXCEPTIONS
        not_found  = 1 ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDIF.

* If needed update logical position in HU header
  IF NOT pv_logpos IS INITIAL AND ps_huhdr-logpos NE pv_logpos.
    ps_huhdr-logpos = pv_logpos.
    CALL METHOD po_oref->/scwm/if_pack_bas~change_huhdr
      EXPORTING
        is_huhdr = ps_huhdr
      IMPORTING
        es_huhdr = ps_huhdr
      EXCEPTIONS
        error    = 1
        OTHERS   = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
    pv_changed_huhdr = 'X'.
* If needed modify internal table from HU header
  ELSEIF pv_logpos IS INITIAL AND NOT ps_huhdr-logpos IS INITIAL.
    ls_rf_pick_hus-logpos = ps_huhdr-logpos.
    MODIFY pt_rf_pick_hus FROM ls_rf_pick_hus INDEX pv_tabix
      TRANSPORTING logpos.
  ENDIF.

ENDFORM.  "update_logpos_huhdr



*......................................................................
* form set_cursor_line
*.....................................................................
*
*   set cursor line
*.....................................................................
FORM set_cursor_line TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
   USING ps_rf_pick_hus TYPE /scwm/s_rf_pick_hus
         ps_rsrc_type TYPE /scwm/s_trsrc_typ
         pv_tabix TYPE sy-tabix
         pv_set_flag TYPE c.

  DATA: lv_start_line TYPE i.
  DATA: ls_rf_pick_hus TYPE /scwm/s_rf_pick_hus.
  DATA: lv_loopc TYPE i.

* Screen begins with the last four lines of the internal table
  CALL METHOD /scwm/cl_rf_dynpro_srvc=>get_loopc
    RECEIVING
      rv_loopc = lv_loopc.

  IF pv_tabix <= lv_loopc.
    /scwm/cl_rf_bll_srvc=>set_line( 1 ).
    /scwm/cl_rf_bll_srvc=>set_cursor_line( pv_tabix ).
  ELSE.
    lv_start_line = pv_tabix - ( lv_loopc - 1 ).
    /scwm/cl_rf_bll_srvc=>set_line( lv_start_line ).
    /scwm/cl_rf_bll_srvc=>set_cursor_line( lv_loopc ).
  ENDIF.

* Close new pick-HU fields for input
  /scwm/cl_rf_bll_srvc=>set_screlm_input_off(
    iv_screlm_name = gc_pmat
    iv_index = pv_tabix ).
  /scwm/cl_rf_bll_srvc=>set_screlm_input_off(
    iv_screlm_name = gc_huident
    iv_index = pv_tabix ).
  /scwm/cl_rf_bll_srvc=>set_screlm_input_off(
    iv_screlm_name = gc_logpos
    iv_index = pv_tabix ).

* If position management is manual
  IF ps_rsrc_type-postn_mngmnt = gc_manual_postn_mng.
*   Open logical position for input
    /scwm/cl_rf_bll_srvc=>set_screlm_input_on(
      iv_screlm_name = gc_logpos
      iv_index = pv_tabix ).
    /scwm/cl_rf_bll_srvc=>set_field('/SCWM/S_RF_PICK_HUS-LOGPOS').
  ENDIF.

ENDFORM.  "set_cursor_line



*......................................................................
* form get_default_material
*.....................................................................
*
*   get default packaging material for the warehouse order
*.....................................................................
FORM get_default_material
  TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
CHANGING ps_nestpt TYPE /scwm/s_rf_nested
         ps_filled_line TYPE /scwm/s_rf_nested.

  DATA: lv_materials TYPE i.
  DATA: lv_pmat TYPE /scwm/de_pmat.
  DATA: ls_one_material TYPE /scwm/s_rf_pick_hus.
  DATA: lt_materials TYPE /scwm/tt_rf_pick_hus.
  DATA: ls_data TYPE /scmb/mdl_matnr_str.

* Check if just one packaging material is proposed for the WO
  lt_materials[] = pt_rf_pick_hus[].
  SORT lt_materials BY pmat_guid.
  DELETE ADJACENT DUPLICATES FROM lt_materials COMPARING pmat_guid.
  DESCRIBE TABLE lt_materials LINES lv_materials.
  IF lv_materials = 1.
    READ TABLE lt_materials INDEX 1 INTO ls_one_material.
    IF NOT ls_one_material-pmat IS INITIAL.
      lv_pmat = ls_one_material-pmat.
    ELSE.
*     Get packaging material from guid
*      CALL FUNCTION 'CONVERSION_EXIT_MDLPD_OUTPUT'
*        EXPORTING
*          input  = ls_one_material-pmat_guid
*        IMPORTING
*          output = lv_pmat.
      TRY.
          CALL FUNCTION '/SCMB/MDL_PRODUCT_READ'
            EXPORTING
              iv_id   = ls_one_material-pmat_guid
            IMPORTING
              es_data = ls_data.
        CATCH /scmb/cx_mdl.
          CLEAR ls_data.
      ENDTRY.
      lv_pmat = ls_data-matnr.
    ENDIF.
    ps_nestpt-pmat = lv_pmat.
    ps_filled_line-pmat = lv_pmat.
  ENDIF.

ENDFORM.  "get_default_material



*......................................................................
* form update_material_list
*.....................................................................
*
*   update packaging material list
*.....................................................................
FORM update_material_list
  TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
   USING ps_rsrc TYPE /scwm/s_rsrc
         ps_who TYPE /scwm/s_who_int
         ps_huhdr TYPE /scwm/s_huhdr_int
         pv_pmat_guid TYPE /scwm/de_matid.

  DATA: ls_material TYPE /scwm/s_rf_pick_hus.
  DATA: lt_materials TYPE /scwm/tt_rf_pick_hus.

  lt_materials[] = pt_rf_pick_hus[].
  DELETE lt_materials WHERE huident = ps_huhdr-huident.
  READ TABLE lt_materials
    WITH KEY pmat_guid = pv_pmat_guid INTO ls_material.
* If no other records with the specific packaging material
  IF sy-subrc NE 0.
*   Fill packaging materials list
    CALL FUNCTION '/SCWM/RF_PICK_PIHUIN_PMLIST'
      EXPORTING
        iv_lgnum       = ps_rsrc-lgnum
        iv_who         = ps_who-who
      TABLES
        pt_rf_pick_hus = pt_rf_pick_hus.
  ENDIF.

ENDFORM.  "update_material_list


*......................................................................
* form set_pointer
*.....................................................................
*
*   set or remove pointer
*.....................................................................
FORM set_pointer TABLES pt_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
   USING pv_huident TYPE /scwm/de_huident
         pv_set_okay TYPE xfeld.

  DATA: ls_rf_pick_hus TYPE /scwm/s_rf_pick_hus.

* Add leading zeros if needed
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = pv_huident
    IMPORTING
      output = pv_huident.

* Modify pointer in found line (Either set or remove)
  READ TABLE pt_rf_pick_hus WITH KEY huident = pv_huident
    INTO ls_rf_pick_hus.

  IF sy-subrc = 0.
    IF ls_rf_pick_hus-pointer IS NOT INITIAL.
      CLEAR ls_rf_pick_hus-pointer.
      MODIFY pt_rf_pick_hus FROM ls_rf_pick_hus INDEX sy-tabix
        TRANSPORTING pointer.
    ELSE.
      ls_rf_pick_hus-pointer = gc_xfeld.
      MODIFY pt_rf_pick_hus FROM ls_rf_pick_hus INDEX sy-tabix
        TRANSPORTING pointer.
    ENDIF.
    pv_set_okay = 'X'.
  ELSE.
    CLEAR pv_set_okay.
  ENDIF.

ENDFORM.  "set_pointer

*......................................................................
* form change_hu_number
*.....................................................................
*
*   Change HU number for a given entry
*.....................................................................
FORM change_hu_number TABLES ct_rf_pick_hus TYPE /scwm/tt_rf_pick_hus
   USING cs_who TYPE /scwm/s_who_int
         cs_nestpt TYPE /scwm/s_rf_nested.

  DATA: lv_sel_hus       TYPE i,
        lv_err_text      TYPE text256,
        lv_ok            TYPE xfeld,
        lv_pmat_old      TYPE /scwm/de_pmat,
        lv_pmat_guid_old TYPE /scwm/de_matid,
        lv_huident       TYPE /scwm/de_huident,
        lv_hu_old        TYPE /scwm/de_huident,
        lv_hukng_old     TYPE /scwm/de_hukng,
        lv_severity      TYPE bapi_mtype.
  DATA: ls_whohu_maint TYPE /scwm/s_whohu_maint,
        ls_whohu_int   TYPE /scwm/s_whohu,
        ls_huhdr       TYPE /scwm/s_huhdr_int.
  DATA: lt_whohu_maint TYPE /scwm/tt_whohu_maint,
        lt_whohu_int   TYPE /scwm/tt_whohu_int,
        lt_bapiret     TYPE bapirettab.

  "Check if ONE line is selected
  LOOP AT ct_rf_pick_hus ASSIGNING FIELD-SYMBOL(<ls_rf_pick_hus>).
    IF <ls_rf_pick_hus>-pointer IS NOT INITIAL.
      ADD 1 TO lv_sel_hus.
      lv_pmat_old  = <ls_rf_pick_hus>-pmat.
      lv_pmat_guid_old = <ls_rf_pick_hus>-pmat_guid.
      lv_hu_old    = <ls_rf_pick_hus>-huident.
      lv_hukng_old = <ls_rf_pick_hus>-hukng.
    ENDIF.
  ENDLOOP.
  IF lv_sel_hus IS INITIAL.
    "Select HU first
*        MESSAGE e199. jq
  ENDIF.
  IF lv_sel_hus > 1.
    "&1 HU selected; select only one HU
*        MESSAGE e838 WITH lv_sel_hus.  jq
  ENDIF.

  WHILE lv_ok = abap_false.
    "Get HU number to replace selected HU in /SCWM/WHOHU
    /scwm/cl_rf_dynpro_srvc=>display_msg_with_answer(
      EXPORTING
        iv_msgid        = '/SCWM/RF_EN'
        iv_msgno        = '374'
        iv_msgty        = 'I'
        iv_err_text     = lv_err_text
      IMPORTING
        ev_answer       = DATA(lv_answer)
        ev_value        = DATA(lv_value)
           ).

    IF lv_answer = /scwm/cl_rf_bll_srvc=>c_answer_cancel.  "F7 pressed
      lv_ok = abap_true.
      /scwm/cl_rf_bll_srvc=>set_prmod(
                         /scwm/cl_rf_bll_srvc=>c_prmod_foreground ).

      CLEAR lv_huident.
      CONTINUE.
    ENDIF.
    IF lv_value IS INITIAL.   "No value entered
      "Enter an HU and proceed
      MESSAGE i113(/scwm/rf_en) INTO lv_err_text.
      CLEAR lv_huident.
      CONTINUE.
    ENDIF.

    "Check if HU is known in the system and
    "  has same packaging material as selected HU
    IF strlen( lv_value ) <= gc_huident_length.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = lv_value
        IMPORTING
          output = lv_huident.
    ELSE.
      MOVE lv_value TO lv_huident.
    ENDIF.

    CALL FUNCTION '/SCWM/HU_READ'
      EXPORTING
        iv_lgnum   = cs_who-lgnum
        iv_huident = lv_huident
      IMPORTING
        es_huhdr   = ls_huhdr
      EXCEPTIONS
        deleted    = 1
        not_found  = 2
        error      = 3
        OTHERS     = 4.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
              INTO lv_err_text.
      CLEAR lv_value.
      CLEAR lv_huident.
      CONTINUE.
    ENDIF.
    IF ( ( ls_huhdr-pmat <> lv_pmat_old AND
           ls_huhdr-pmat IS NOT INITIAL ) OR
         ( ls_huhdr-pmat_guid <> lv_pmat_guid_old AND
           ls_huhdr-pmat_guid IS NOT INITIAL ) ).
      "Only HU of type &1 is allowed
      MESSAGE i839(/scwm/rf_en) WITH lv_pmat_old INTO lv_err_text.
      CLEAR lv_huident.
      CONTINUE.
    ENDIF.
    "Check if new HU number is already part of ct_rf_pick_hus
    READ TABLE ct_rf_pick_hus TRANSPORTING NO FIELDS
      WITH KEY huident = lv_huident.
    IF sy-subrc = 0.
      MESSAGE i130(/scwm/rf_en) WITH cs_who-who INTO lv_err_text.
      CLEAR lv_huident.
      CONTINUE.
    ENDIF.

    lv_ok = abap_true.
  ENDWHILE.

  IF lv_huident <> lv_hu_old AND
     lv_huident IS NOT INITIAL.
    "Change HU number via /SCWM/WHO_WHOHU_MAINT.
    ls_whohu_maint-huident = lv_huident.
    ls_whohu_maint-hukng = lv_hukng_old.
    ls_whohu_maint-pmat_guid = lv_pmat_guid_old.
    ls_whohu_maint-updkz = 'U'.
    APPEND ls_whohu_maint TO lt_whohu_maint.

    CALL FUNCTION '/SCWM/WHO_WHOHU_MAINT'
      EXPORTING
        iv_lgnum    = cs_who-lgnum
        iv_who      = cs_who-who
        it_whohu    = lt_whohu_maint
      IMPORTING
        ev_severity = lv_severity
        et_bapiret  = lt_bapiret
        et_whohu    = lt_whohu_int.

    COMMIT WORK AND WAIT.
    CALL METHOD /scwm/cl_tm=>cleanup( ).

    READ TABLE ct_rf_pick_hus ASSIGNING <ls_rf_pick_hus>
      WITH KEY hukng = lv_hukng_old.
    IF sy-subrc = 0.
      "Set the new HU number
      <ls_rf_pick_hus>-huident = lv_huident.
      "Remove pointer
      CLEAR <ls_rf_pick_hus>-pointer.
    ENDIF.
  ENDIF.

  IF lv_answer = /scwm/cl_rf_bll_srvc=>c_answer_cancel.
    READ TABLE ct_rf_pick_hus ASSIGNING <ls_rf_pick_hus>
      WITH KEY hukng = lv_hukng_old.
    IF sy-subrc = 0.
      "Remove pointer
      CLEAR <ls_rf_pick_hus>-pointer.
    ENDIF.
  ENDIF.

  CLEAR cs_nestpt-rfhu.

ENDFORM.   "change_hu_number
