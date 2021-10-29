$(document).ready(function() {
  new FullCalendarConfig($("#calendar"), {
    header: {
      left: 'title',
      center: '',
      right: 'prev,next month',
    }
  }).init();
});
