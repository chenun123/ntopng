<h4 class='mb-2'>顶层应用程序协议</h4>
<div class='my-2'>
   <div class="pie-chart m-auto" id="topApplicationProtocols"></div>
</div>
<span class="help-block">请单击应用程序查看有关详细信息。</span>
<div class='my-3'></div>
<script type='text/javascript'>
window.onload = () => {
   let refresh = 3000 /* ms */;
   do_pie("#topApplicationProtocols", '@HTTP_PREFIX@/lua/iface_ndpi_stats.lua', { ndpistats_mode: "sinceStartup" }, "", refresh);
}
</script>
