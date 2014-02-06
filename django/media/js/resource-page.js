function setVar(name, value, triggers){
    triggers = typeof triggers !== 'undefined' ? triggers : true;
    if (triggers){
        $('#' + name).val(value).trigger('change');
    } else {
        $('#' + name).val(value);
    }
}

function getVar(name){
    return $('#' + name).val();
}

function showPositions(html){
    $('#subscriptions-table').html(html);
    $('#subscriptions-table').show();
    //$('#slider').show();
    //$('.spinner').hide();
}

function hidePositions(){
    //$('.spinner').show();
    //$('#slider').hide();
    $('#subscriptions-table').hide();
}

function requestFailed(jqXHR, textStatus, errorThrown){
    var html = '<h2 class="centered">Ошибка при получении данных</h2>';
    showPositions(html);
}

function getData(selector, getter){
    getter = typeof getter !== 'undefined' ? getter : function (elem) {
        return elem.id;
    };
    var s = '[' + $(selector).map(getter).join() + ']';
    return s;
}

function getPositions(params){
    // здесь идёт параvетр по умолчанию для действия success
    var on_success = typeof params.on_success !== 'undefined' ? params.on_success : showPositions;

    // а здесь -- для действия fail
    var on_fail = typeof params.on_fail !== 'undefined' ? params.on_fail : requestFailed;

    // скрыть таблицу и показать спиннер
    hidePositions();

    data = {};

    // порядок и параметр сортировки по умолчанию
    if ((typeof params.sorting_by !== 'undefined') && (typeof params.asc !== 'undefined')){
        data.sorting_by = params.sorting_by;
        data.asc = params.asc;
    }

    data.view = getVar('view-id');
    data.region = getVar('region-id');
    data.since = getVar('date-since');
    data.until = getVar('date-until');

    // получить позиции
    $.ajax({
        type: 'GET',
        url: getVar('url_positions'),
        data: data,
        dataType: 'html'
    }).done(on_success).fail(on_fail);
}

function checkIfFresh(on_true, on_false, on_fail){
    // параметр по-умолчанию для on_fail
    on_fail = typeof on_fail !== 'undefined' ? on_fail : requestFailed;

    var data = {};
    data.timestamp = getVar('last-changed');
    $.ajax({
        type: 'GET',
        url:  getVar('url_fresh'),
        data: data,
        dataType : 'text'
    }).done(function(text) {
        if (text == 'True'){
            on_true();
        }
        else {
            on_false();
        }
    }).fail(on_fail);
}

function saveSortingOrder(success){
    var data = {};
    data.sorting_order = getData('.sorting-order');
    $.ajax({
        type: 'POST',
        url:  getVar('url_save'),
        data: data,
    }).done(success);
}

function syncronizeTime(){
    $.ajax({
        type: 'GET',
        url:  getVar('url_sync'),
    }).done(function (time){
        setVar('last-changed', time);
    });
}

function dragUpdate(e, ui){
    checkIfFresh(
        function(){
            saveSortingOrder(syncronizeTime);
        },
        function(){
            alert("Данные были изменены другим пользователем");
        }
    );
}

function helper(e, ui) {
    ui.children().each(function() {
        $(this).width($(this).width());
    });
    return ui;
}

function sliderValuesChanging(e, data){
    setVar('date-since', data.values.min.toISOString(), false);
    setVar('date-until', data.values.max.toISOString());
}

//

var add_view = function(){
    var data={};
    data.name=getVar("view-field");
    var url = getVar("url_create_view");
    $("#alert-success").show();
    $.ajax({
        type: 'POST',
        url: url,
        data: data,
        dataType: 'text'
    })//.done(entries);
}

function ajax_view_dropdown(){
    $(".view_dropdown>span").html($(this).html());
    setVar('view-id', $(this).data("view_id"));
}


function button_edit_click() {
    getPositions(function(html){
            showPositions(html);
            //$(".well").show();
            $("#positions-table > tbody").sortable({deactivate: dragUpdate,
                                                    helper: helper,
                                                    axis: "y"}).disableSelection();
            $("#positions-table > tbody").sortable("enable");
            $("#button-edit").hide();
            $("#button-done").show();
            $(".affix-control").show();
    });
}
function slider(html){
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"];
    $("#slider").dateRangeSlider({
        bounds: {
            min: new Date($('#slider').data('date_since')),
            max: new Date($('#slider').data('date_until'))
        },
        defaultValues: {
            min: new Date($('#slider').data('date_mid')),
            max: new Date($('#slider').data('date_until'))
        },
        arrows:false,

        scales: [{
               first: function(min, max){
                   if ((min.getDate() == 1) ||
                       ((min.getMonth() == max.getMonth()) && (min.getFullYear() == max.getFullYear()))) 
                       return min;
                   else
                       return new Date(min.getFullYear(), min.getMonth()+1, 1);
              },
               end: function(value) {return value; },
               next: function(value){
                   var next = new Date(value);
                   return new Date(next.setMonth(value.getMonth() + 1));
               },
              label: function(val){ return months[val.getMonth()]; },
              format: function(tickContainer, tickStart, tickEnd){
                tickContainer.addClass("myCustomClass");
              }
        }],
        step:{
            days: 1
        }
    });
    setVar('date-since', $('#slider').dateRangeSlider('min').toISOString(), false);
    setVar('date-until', $('#slider').dateRangeSlider('max').toISOString(), false);
    $('#slider').bind('valuesChanged', sliderValuesChanging);
}

function click_range_dropdown(){
    var today = new Date();
    var max = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    var min = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    min.setDate(min.getDate()-$(this).data("range"));
    $("#slider").dateRangeSlider("bounds", min, max);
}


function pill_region_click(){
    $('.pill.active').removeClass("active");
    $(this).parent().addClass("active");
    setVar("region-id", $(this).data("region"))
 }


function button_export_click() {
        var values = $("#slider").dateRangeSlider("values");
        var min = values.min.toISOString();
        var max = values.max.toISOString();
        $(this).attr('href', $(this).data('url') + '?date_since=' + min + '&date_until=' + max);
}

function button_done_click(){
    $("#button-edit").show();
    $("#button-done").hide();
    $(".affix-control").hide();
}

function select_all_click(){
    $("table#positions-table tbody tr").addClass("success");
    $("#select_all").hide();
    $("#reset").show();
}

function reset_click(){
        $("table#positions-table tbody tr").removeClass("success");
        $("#select_all").show();
        $("#reset").hide();
}

function create_view_click(){
    $('#modal-body1').html('Вы уверены, что хотите создать представление и добавить в него выбранные запросы?'+
        '\n<input type="text" class="form-control" placeholder="Имя представления" id="view-field">');
    $('.modal-title1').html('Создать представление?');
    $('#btn-ok').off("click");
    $('#btn-ok').click(add_view);
    $('#modal-add-entries').modal();
}
function delete_change_click() {
    $('#modal-body1').html('Вы уверены, что хотите удалить выбранные запросы?');
    $('.modal-title1').html('Удалить запросы?');
    $('#btn-ok').off("click");
    $('#btn-ok').click(function(){
        entries($("#url_delete_entries").val());
        $("#alert-delete").show();
    });
    $('#modal-add-entries').modal();
}
function view_clickable_click() {
    $('#modal-body1').html('Вы уверены, что хотите добавить выбранные запросы в представление '+$(this).data("name")+' ?');
    $('.modal-title1').html('Добавление запросов в представление');
    $('#btn-ok').off("click");
    $('#btn-ok').removeData();
    $('#btn-ok').data('url', $(this).data('url'));
    $("#btn-ok").click(function() {
        entries($(this).data('url'));
        $(".alert-success").show();
    });
    $('#modal-add-entries').modal();
}
function tr_click(){
    $(this).toggleClass("success");
}



