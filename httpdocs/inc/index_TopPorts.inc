<div class="row">
   <div class='col'>
      <h4>顶级客户端端口</h4>
      <div class="pie-chart m-auto" id="topClientPorts"></div>
      <span class="help-block">单击端口以获取更多信息。</span>
   </div>
   <div class='col'>
      <h4>顶级客户端端口</h4>
      <div class="pie-chart m-auto" id="topServerPorts"></div>
      <span class="help-block">单击端口以获取更多信息。</span>
   </div>
</div>
<div class='my-3'></div>
<script type='text/javascript'>

window.onload = () => {
   let refresh = 3000 /* ms */;
   do_pie("#topClientPorts", '@HTTP_PREFIX@/lua/iface_ports_list.lua', { clisrv: "client" }, "", refresh);
   do_pie("#topServerPorts", '@HTTP_PREFIX@/lua/iface_ports_list.lua', { clisrv: "server" }, "", refresh);
}

</script>


