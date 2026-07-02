CLASS z2ui5_cl_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.
    DATA ms_cds TYPE z2ui5_cds_test_popup.
    DATA mv_vh_result TYPE string.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF cs_event,
        open_action_dialog TYPE string VALUE `OPEN_ACTION_DIALOG`,
        open_value_help    TYPE string VALUE `OPEN_VALUE_HELP`,
        open_object_page   TYPE string VALUE `OPEN_OBJECT_PAGE`,
        open_list_report   TYPE string VALUE `OPEN_LIST_REPORT`,
        open_list_report2  TYPE string VALUE `OPEN_LIST_REPORT2`,
        open_list_material TYPE string VALUE `OPEN_LIST_MATERIAL`,
        open_list_travel   TYPE string VALUE `OPEN_LIST_TRAVEL`,
        open_worklist      TYPE string VALUE `OPEN_WORKLIST`,
        open_overview_page TYPE string VALUE `OPEN_OVERVIEW_PAGE`,
      END OF cs_event.
ENDCLASS.



CLASS z2ui5_cl_cds_test IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).

      ms_cds-searchcountry = `US`.

      DATA(lo_view) = z2ui5_cl_xml_view=>factory( ).
      DATA(lo_page) = lo_view->shell( )->page( title = `abap2UI5 - CDS Framework Demo` ).

      "=== Popup Section ===
      DATA(lo_panel1) = lo_page->panel( headertext = `Popups (sub-app navigation)` ).
      DATA(lo_hbox1) = lo_panel1->hbox( class = `sapUiSmallMarginBottom` ).
      lo_hbox1->button(
        text  = `Action Dialog`
        press = client->_event( cs_event-open_action_dialog )
        type  = `Emphasized`
        icon  = `sap-icon://popup-window` ).
      lo_hbox1->button(
        text  = `Value Help`
        press = client->_event( cs_event-open_value_help )
        icon  = `sap-icon://value-help` ).

      "=== Page Section ===
      DATA(lo_panel2) = lo_page->panel( headertext = `Full Page Apps (sub-app navigation)` ).
      DATA(lo_hbox2) = lo_panel2->hbox( class = `sapUiSmallMarginBottom` ).
      lo_hbox2->button(
        text  = `Object Page`
        press = client->_event( cs_event-open_object_page )
        icon  = `sap-icon://detail-view` ).
      lo_hbox2->button(
        text  = `List Report (I_Country)`
        press = client->_event( cs_event-open_list_report )
        icon  = `sap-icon://list` ).
      lo_hbox2->button(
        text  = `List Report (I_CompanyCode)`
        press = client->_event( cs_event-open_list_report2 )
        icon  = `sap-icon://list` ).
      lo_hbox2->button(
        text  = `List Report (I_Material)`
        press = client->_event( cs_event-open_list_material )
        icon  = `sap-icon://product` ).
      lo_hbox2->button(
        text  = `List Report (/DMO/ Travel)`
        press = client->_event( cs_event-open_list_travel )
        icon  = `sap-icon://flight` ).
      lo_hbox2->button(
        text  = `Worklist`
        press = client->_event( cs_event-open_worklist )
        icon  = `sap-icon://task` ).
      lo_hbox2->button(
        text  = `Overview Page`
        press = client->_event( cs_event-open_overview_page )
        icon  = `sap-icon://overview-chart` ).

      "=== Current Values ===
      DATA(lo_panel3) = lo_page->panel( headertext = `Current Action Dialog Values` ).
      DATA(lo_form) = lo_panel3->simple_form(
        editable = abap_false
        layout   = `ResponsiveGridLayout` )->content( `form` ).

      lo_form->label( `Country` ).
      lo_form->text( client->_bind( ms_cds-searchcountry ) ).
      lo_form->label( `Date` ).
      lo_form->text( client->_bind( ms_cds-newdate ) ).
      lo_form->label( `Message Type` ).
      lo_form->text( client->_bind( ms_cds-messagetype ) ).
      lo_form->label( `Description` ).
      lo_form->text( client->_bind( ms_cds-description ) ).
      lo_form->label( `Value Help Result` ).
      lo_form->text( client->_bind( mv_vh_result ) ).

      client->view_display( lo_view->stringify( ) ).
      RETURN.

    ENDIF.

    "=== Action Dialog ===
    IF client->check_on_event( cs_event-open_action_dialog ).
      DATA(lo_dialog) = NEW z2ui5_cl_cds_action_dialog(
        val   = ms_cds
        title = `Enter Parameters` ).
      client->nav_app_call( CAST #( lo_dialog ) ).
      RETURN.
    ENDIF.

    "=== Object Page ===
    IF client->check_on_event( cs_event-open_object_page ).
      DATA ls_op TYPE z2ui5_cds_test_op.
      ls_op-orderid = `PO-48865`.
      ls_op-customername = `Robotech Industries`.
      ls_op-priority = `High`.
      ls_op-prioritycrit = 1.
      ls_op-status = `In Delivery`.
      ls_op-statuscrit = 3.
      ls_op-orderdate = sy-datum - 30.
      ls_op-deliverydate = sy-datum + 5.
      ls_op-changedon = sy-datum.
      ls_op-netamount = '12897.00'.
      ls_op-taxamount = '2450.43'.
      ls_op-grossamount = '15347.43'.
      ls_op-currency = `EUR`.
      ls_op-createdby = sy-uname.
      ls_op-createdon = sy-datum - 30.
      ls_op-changedby = sy-uname.
      ls_op-notes = `Delivery expected next week. Customer confirmed receiving dock availability.`.
      DATA(lo_op) = NEW z2ui5_cl_cds_object_page(
        val   = ls_op
        title = `Purchase Order` ).
      client->nav_app_call( CAST #( lo_op ) ).
      RETURN.
    ENDIF.

    "=== List Report ===
    IF client->check_on_event( cs_event-open_list_report ).
      DATA(lo_lr) = NEW z2ui5_cl_cds_list_report(
        cds_view_name = `I_COUNTRY`
        title         = `Countries` ).
      client->nav_app_call( CAST #( lo_lr ) ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-open_list_report2 ).
      DATA(lo_lr2) = NEW z2ui5_cl_cds_list_report(
        cds_view_name = `I_COMPANYCODE`
        title         = `Company Codes` ).
      client->nav_app_call( CAST #( lo_lr2 ) ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-open_list_material ).
      DATA(lo_lr3) = NEW z2ui5_cl_cds_list_report(
        cds_view_name = `I_MATERIAL`
        title         = `Materials`
        max_rows      = 200 ).
      client->nav_app_call( CAST #( lo_lr3 ) ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-open_list_travel ).
      DATA(lo_lr4) = NEW z2ui5_cl_cds_list_report(
        cds_view_name = `/DMO/I_TRAVEL_U`
        title         = `Travels (DMO Flight Scenario)` ).
      client->nav_app_call( CAST #( lo_lr4 ) ).
      RETURN.
    ENDIF.

    "=== Worklist ===
    IF client->check_on_event( cs_event-open_worklist ).
      DATA(lo_wl) = NEW z2ui5_cl_cds_worklist(
        cds_view_name = `I_CURRENCY`
        title         = `Currencies` ).
      client->nav_app_call( CAST #( lo_wl ) ).
      RETURN.
    ENDIF.

    "=== Overview Page ===
    IF client->check_on_event( cs_event-open_overview_page ).
      DATA(lo_ov) = NEW z2ui5_cl_cds_overview_page(
        title = `Business Overview`
        cards = VALUE #(
          ( cds_view_name = `I_COUNTRY`  title = `Countries`  card_type = `TABLE` max_rows = 5 )
          ( cds_view_name = `I_CURRENCY` title = `Currencies` card_type = `TABLE` max_rows = 5 )
          ( cds_view_name = `I_LANGUAGE` title = `Languages`  card_type = `KPI` ) ) ).
      client->nav_app_call( CAST #( lo_ov ) ).
      RETURN.
    ENDIF.

    "=== Value Help ===
    IF client->check_on_event( cs_event-open_value_help ).
      DATA(lo_vh) = NEW z2ui5_cl_cds_value_help(
        cds_view_name = `I_COUNTRY`
        element       = `Country`
        title         = `Select Country` ).
      client->nav_app_call( CAST #( lo_vh ) ).
      RETURN.
    ENDIF.

    "=== Handle return from sub-apps ===
    IF client->check_on_navigated( ).
      IF client->check_app_prev_stack( ).
        DATA(lo_prev) = client->get_app_prev( ).

        TRY.
            DATA(lo_action) = CAST z2ui5_cl_cds_action_dialog( lo_prev ).
            IF lo_action->was_confirmed( ).
              DATA(lr_result) = lo_action->result( ).
              ms_cds = lr_result->*.
              client->message_toast_display( `Parameters updated` ).
            ELSE.
              client->message_toast_display( `Cancelled` ).
            ENDIF.
          CATCH cx_sy_move_cast_error.
            TRY.
                DATA(lo_vh_prev) = CAST z2ui5_cl_cds_value_help( lo_prev ).
                IF lo_vh_prev->was_confirmed( ).
                  mv_vh_result = lo_vh_prev->result_value( ).
                  ms_cds-searchcountry = mv_vh_result.
                  client->message_toast_display( |Selected: { mv_vh_result }| ).
                ELSE.
                  client->message_toast_display( `Cancelled` ).
                ENDIF.
              CATCH cx_sy_move_cast_error.
            ENDTRY.
        ENDTRY.
      ENDIF.
      client->view_model_update( ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
