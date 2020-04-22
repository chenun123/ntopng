            <h4>顶级流对话者：活动</h4>
	    <div class="pie-chart" id="topSenders"></div>
<span class="help-block" style="color: #dddddd;">请单击主机查看有关详细信息。</span>
<script type='text/javascript'>

window.onload=function() {
   var refresh = 3000 /* ms */;

   do_pie("#topSenders", '@HTTP_PREFIX@/lua/get_top_realtime.lua?module=top_talkers', { senders_receivers : "senders" }, "", refresh);
}

</script>
