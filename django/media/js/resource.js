function entries(url){
    var s="[";
    var list = $("tr.success");
    var i = 0;
    for (i = 0; i < list.length; i++){
        s += $(list[i]).data("id") ;
        if (i!==list.length-1)  s += ',';
    }
    s += ']';
    var data={};
    data.entries=s;
    console.log("2");
    $.ajax({
        type: 'POST',
        url: url,
        data: data,
        dataType: 'html'
    });
}

var add_view = function(){
    var data={};
    data.name=$("#view-field").val();
    var url = $("#url_create_view").val();
    $("#alert-success").show();
    console.log("3");
    $.ajax({
        type: 'POST',
        url: url,
        data: data,
        dataType: 'text'
    }).done(entries);
}


























function ajax_view_dropdown(){
    $(".view_dropdown>span").html($(this).html());
    console.log("4");
    var data = {};
    data.view = $(this).data("view_id");
    $.ajax({
        type: 'GET',
        url: $(this).data("url"),
        data: data,
        dataType: 'html'
    }).done(function(html){
        $('#positions-slider').html(html);
        $(".pill:first-child .pill-region").click();
    });
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
    $('#subscriptions_table').html(html);
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
                       ((min.getMonth() == max.getMonth()) && (min.getFullYear() == max.getFullYear()))) //здесь всё было правильно кроме скобок
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
    $("#slider").bind("valuesChanged", sliderValuesChanging);
    var data = {};
    data.values = {};
    data.values.max = new Date($('#slider').data('date_until'));
    data.values.min = new Date($('#slider').data('date_mid'));
    sliderValuesChanging('', data);
    syncronizeTime();
    //$('#button-done').hide();
    //$("#slider").append('<img id="prev" src="'+$("#img-left").val()+'" style="position: absolute; left: -10px;" data-url="'+$("#url-prev").val()+'">');
    //$("#slider").append('<img id="next" src="'+$("#img-right").val()+'" style="position: absolute; right: -10px;" data-url="'+$("#url-next").val()+'">');
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
    console.log("5");
    $.ajax({
        type: 'GET',
        url: $(this).data("url"),
        data: {since: $("#since").val(), until: $("#until").val()},
        dataType: 'html'
    }).done(slider);
}















function positions_slider(html){
     $('#inner_positions_table').html(html);
     $('#button-done').hide();
}

function arrow_click(){
    console.log("1");
    $.ajax({
        type: 'GET',
        url: $(this).data("url"),
        dataType: 'html'
    }).done(slider);
}

function button_export_click() {
        var values = $("#slider").dateRangeSlider("values");
        var min = values.min.toISOString();
        var max = values.max.toISOString();
        $(this).attr('href', $(this).data('url') + '?date_since=' + min + '&date_until=' + max);
}
$("#alert-success").hide();
$("#alert-delete").hide();
function button_done_click(){
    $("#button-edit").show();
    $("#button-done").hide();
    $(".affix-control").hide();
}
$("#reset").hide();
$(".affix-control").hide();
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
$('#button-done').hide();
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
