--
-- (C) 2013-20 - ntop.org
--

require "os"
require "lua_utils"
local ts_utils = require("ts_utils_core")

local template = require "template_utils"
local page_utils = require "page_utils"

local have_nedge = ntop.isnEdge()
local info = ntop.getInfo(true)
local is_admin = isAdministrator()


interface.select(ifname)
local iface_id = interface.name2id(ifname)
local _ifstats = interface.getStats()
local ifid = _ifstats.id

if not interface.isPcapDumpInterface() and not have_nedge then
   if(ifname ~= nil) then
      maxSpeed = getInterfaceSpeed(_ifstats.id)
   end
   -- io.write(maxSpeed)
   if((maxSpeed == "") or (maxSpeed == nil)) then
      -- if the speed in not custom we try to read the speed from the interface
      -- and, as a final resort, we use 1Gbps
      if tonumber(_ifstats.speed) ~= nil then
	 maxSpeed = tonumber(_ifstats.speed) * 1e6
      else
	 maxSpeed = 1000000000 -- 1 Gbit
      end
   else
      -- use the user-specified custom value for the speed
      maxSpeed = tonumber(maxSpeed)*1000000
   end
end -- closes interface.isPcapDumpInterface() == false

if not info.oem then

print [[
<footer id="n-footer">
	<div class="container-fluid border-top">
		<div class="row mt-2">
			<div class="col-12 text-right">
				<small>
					<div class="text-right">
						<i class="fas fa-clock"></i> <div class="d-inline-block" id='network-clock'></div> | ]] print(i18n("about.uptime")) print[[: <div class="d-inline-block" id='network-uptime'></div>
					</div>
				</small>
			</div>
     	</div>
   </div>
</footer>
]]

else -- info.oem
  print[[<div class="col-12 text-right">
    <small>
	    <div class="text-right">
		    <i class="fas fa-clock"></i> <div class="d-inline-block" id='network-clock'></div> | ]] print(i18n("about.uptime")) print[[: <div class="d-inline-block" id='network-uptime'></div>
	    </div>
    </small>
</div>]]
end

local traffic_peity_width = "64"

if ts_utils.getDriverName() == "influxdb" then

   local msg = ntop.getCache("ntopng.cache.influxdb.last_error")
   if not isEmptyString(msg) then
	print([[
		<script type="text/javascript">
			$("#influxdb-error-msg-text").html("]].. (msg:gsub('"', '\\"')) ..[[");
			$("#influxdb-error-msg").show();
		</script>
	]])
   end
end

-- Toogle System Interface

-- render switchable system view

print([[
	<script type="text/javascript">

	   const toggle_system_flag = (is_system_switch = false, $form = null) => {

		  // if form it's empty it means the call was not invoked
		  // by a form request
		  // prevent the non admin user to switch in system interface
		  const is_admin = ]].. (is_admin and "true" or "false") ..[[;
		  const flag = (is_system_switch && is_admin) ? "1" : "0";

		  $.get(`]].. (ntop.getHttpPrefix()) ..[[/lua/switch_system_status.lua`, {
			 system_interface: flag,
			 csrf: "]].. ntop.getRandomCSRFValue() ..[["
		  }, function(data) {

			 if (data.success && $form == null) location.href = '/';
			 if (data.success && $form != null) $form.submit();
			 if (!data.success) {
				console.error("An error has occurred!");
			 }

		  });
	   }
	]])

	if (not page_utils.is_system_view()) then

		print([[
		$(document).ready(function() {
			$("#btn-trigger-system-mode").click(function(e) {
				toggle_system_flag(]].. (is_admin and "true" or "false") ..[[);
			});
		});
		]])
	end

print([[
	</script>
]])

-- End of Toggle System Interface

-- Only show the message if the host protocol/category timeseries are enabled
local message_enabled = (areHostL7TimeseriesEnabled(ifid) or areHostCategoriesTimeseriesEnabled(ifid)) and
   (ts_utils.getDriverName() ~= "influxdb") and
   (ntop.getPref("ntopng.prefs.disable_ts_migration_message") ~= "1")

print [[
<script type="text/javascript">

]]

if not info.oem then

	-- Blog Notification click handling
	print([[
		$(document).ready(function() {

			let csrf_notification = "]].. ntop.getRandomCSRFValue() ..[[";
			function blogNotifcationClick(e) {

				if (e.type == "mousedown" && (e.metaKey || e.ctrlKey || e.which !== 2)) return;

				const id = $(this).data('id');
				$.post(`]].. ntop.getHttpPrefix() ..[[/lua/update_blog_posts.lua`, {
					blog_notification_id: id,
					csrf: csrf_notification
				},
				(data) => {

					if (data.success) {
						$(this)
							.off('click').off('mousedown')
							.attr('data-read', 'true').data('read', 'true')
							.find('.badge').remove();
						const count = $(`.blog-notification[data-read='false']`).length;

						if (count == 0) {
							$('.notification-bell').remove();
							return;
						}
						$('.notification-bell').html(count);
					}
					csrf_notification = data.csrf;
				});
			}

			$(`.blog-notification[data-read='false']`)
				.click(blogNotifcationClick)
				.mousedown(blogNotifcationClick);
		});
	]])

	-- Major release check
	local latest_major = ntop.getCache("ntopng.cache.major_release")

	latest_major = trimSpace(string.gsub(latest_major, "\n", ""))

	if isEmptyString(latest_major) then
		print[[
		$.ajax({
		type: 'GET',
		url: ']]
			print (ntop.getHttpPrefix())
			print [[/lua/check_major_release.lua',
		data: {},
		success: function(rsp) {
			if(rsp && rsp.msg) {
			$("#ntopng_update_available").html(rsp.msg);
			$("#major-release-alert").show();
			}
		}
		});
		]]
	else
		local msg = get_version_update_msg(info, latest_major)

		if not isEmptyString(msg) then
		print[[
		$("#ntopng_update_available").html(`]] print(msg) print[[`);
		$("#major-release-alert").show();
		]]
		end
	end
end

print[[
var is_historical = false;

function checkMigrationMessage(data) {
  const max_local_hosts = 500;
  let enabled = ]] print(ternary(message_enabled, "true", "false")) print[[;

  if(enabled && (data.num_local_hosts > max_local_hosts))
    $("#move-rrd-to-influxdb").show();
}

$("#move-rrd-to-influxdb, #host-id-message-warning, #influxdb-error-msg").on("close.bs.alert", function() {
  $.ajax({
		type: 'POST',
		url: ']] print (ntop.getHttpPrefix()) print [[/lua/update_prefs.lua',
		data: {
			csrf: ']] print(ntop.getRandomCSRFValue()) print[[',
			action: this.id,
			ifid: ]] print(string.format("%u", _ifstats.id)) print[[,
		}
	});
});

let updatingChart_upload = $(".network-load-chart-upload").show().peity("line", { width: ]] print(traffic_peity_width) print[[, max: null });
let updatingChart_download = $(".network-load-chart-download").show().peity("line", { width: ]] print(traffic_peity_width) print[[, max: null, fill: "lightgreen"});
let updatingChart_total = $(".network-load-chart-total").show().peity("line", { width: ]] print(traffic_peity_width) print[[, max: null});

const footerRefresh = function() {
    $.ajax({
      type: 'GET',
	  url: ']]print (ntop.getHttpPrefix()) print [[/lua/rest/get/interface/data.lua',
	  data: { ifid: ]] print(tostring(ifid)) print[[ },
	  /* error: function(content) { alert("JSON Error (session expired?): logging out"); window.location.replace("]] print (ntop.getHttpPrefix()) print [[/lua/logout.lua");  }, */
	  success: function(rsp) {
	  try {
	      var values = updatingChart_upload.text().split(",")
	      var values1 = updatingChart_download.text().split(",")
	      var values2 = updatingChart_total.text().split(",")

	      var pps = rsp.throughput_pps;
	      var bps = rsp.throughput_bps * 8;
	      var bps_upload = rsp.throughput.upload.bps * 8;
	      var bps_download = rsp.throughput.download.bps * 8;

	      if(rsp.remote_pps != 0) {
		pps = Math.max(rsp.remote_pps, 0);
	      }
	      if(rsp.remote_bps != 0) {
		bps = Math.max(rsp.remote_bps, 0);
		bps = Math.min(bps, rsp.speed * 1e6);
	      }

	      values.shift();
	      values.push(bps_upload);
	      updatingChart_upload.text(values.join(",")).change();
	      values1.shift();
	      values1.push(-bps_download);
	      updatingChart_download.text(values1.join(",")).change();
	      values2.shift();
	      values2.push(bps);
	      updatingChart_total.text(values2.join(",")).change();
	      var v = bps_upload - bps_download;

]]

if (interface.isPcapDumpInterface() == false) and (not have_nedge) then
   print[[

		var v = Math.round(Math.min((bps*100)/]] print(string.format("%u", maxSpeed)) print[[, 100));
		$('#networkload').html(v+"%");
]]
end

print[[
		$('#chart-upload-text').html(""+bitsToSize(bps_upload, 1000));
		$('#chart-download-text').html(""+bitsToSize(bps_download, 1000));
		$('#chart-total-text').html(""+bitsToSize(bps_upload + bps_download, 1000));
     ]]

-- system_view_enabled is defined inside menu.lua

print[[
		$('#network-clock').html(`${rsp.localtime}`);
		$('#network-uptime').html(`${rsp.uptime}`);

		let msg = `<li class='nav-item mx-2'><div class='d-flex'>`;

		if (rsp.system_host_stats.cpu_states) {
            const iowait = ']] print(i18n("about.iowait")) print[[: ' + formatValue(rsp.system_host_stats.cpu_states.iowait) + "%";
            const active = ']] print(i18n("about.active")) print[[: ' + formatValue(rsp.system_host_stats.cpu_states.user + rsp.system_host_stats.cpu_states.system  + rsp.system_host_stats.cpu_states.nice + rsp.system_host_stats.cpu_states.irq + rsp.system_host_stats.cpu_states.softirq + rsp.system_host_stats.cpu_states.guest + rsp.system_host_stats.cpu_states.guest_nice) + "%";
            const idle = ']] print(i18n("about.idle")) print[[: ' + formatValue(rsp.system_host_stats.cpu_states.idle + rsp.system_host_stats.cpu_states.steal) + "%";
            $('#cpu-states').html(iowait + " / " + active + " / " + idle);
        }

		if (rsp.system_host_stats.mem_total != undefined) {
		   var mem_total = rsp.system_host_stats.mem_total;
		   var mem_used = rsp.system_host_stats.mem_used;
		   var mem_used_ratio = mem_used / mem_total;

		   mem_used_ratio = mem_used_ratio * 100;
		   mem_used_ratio = Math.round(mem_used_ratio * 100) / 100;
		   mem_used_ratio = mem_used_ratio + "%";

		   $('#ram-used').html(']] print(i18n("ram_used")) print[[: ' + mem_used_ratio + ' / ]] print(i18n("ram_available")) print[[: ' + bytesToSize((mem_total - mem_used) * 1024) + ' / ]] print(i18n("ram_total")) print[[: ' + bytesToSize(mem_total * 1024));
		   $('#ram-process-used').html(']] print(i18n("ram_used")) print[[: ' + bytesToSize(rsp.system_host_stats.mem_ntopng_resident * 1024));
		}

                if(rsp.system_host_stats.dropped_alerts) {
                  const drop_pct = rsp.system_host_stats.dropped_alerts / (rsp.system_host_stats.dropped_alerts + rsp.system_host_stats.written_alerts) * 100;
                  $('#dropped-alerts').html(fint(rsp.system_host_stats.dropped_alerts) + " [" + fpercent(drop_pct) + "]");
                } else {
                  $('#dropped-alerts').html("0");
                }
		$('#stored-alerts').html(rsp.system_host_stats.written_alerts ? fint(rsp.system_host_stats.written_alerts) : "0");
		$('#alerts-queries').html(rsp.system_host_stats.alerts_queries ? fint(rsp.system_host_stats.alerts_queries) : "0");

		if (rsp.system_host_stats.cpu_load !== undefined) $('#cpu-load-pct').html(ffloat(rsp.system_host_stats.cpu_load));

        if(rsp.out_of_maintenance) {
          msg += "<a href=\"https://www.ntop.org/support/faq/how-can-i-renew-maintenance-for-commercial-products/\" target=\"_blank\"><span class=\"badge badge-warning\">]] print(i18n("about.maintenance_expired", {product=info["product"]})) print[[ <i class=\"fas fa-external-link-alt\"></i></span></a> ";
        }

        if(rsp.degraded_performance) {
		   	msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/system_interfaces_stats.lua?page=internals&tab=periodic_activities&periodic_script_issue=any_issue\">"
		    msg += "<span class=\"badge badge-warning\"><i class=\"fas fa-exclamation-triangle\" title=\"]] print(i18n("internals.degraded_performance")) print[[\"></i></span></a>";
		}

		if ((rsp.engaged_alerts > 0 || rsp.alerted_flows > 0) && ]] print(ternary(hasAllowedNetworksSet(), "false", "true")) print[[ && (!system_view_enabled)) {

		   var error_color = "#B94A48";

		   if(rsp.engaged_alerts > 0) {
		   	msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/show_alerts.lua\">"
		    msg += "<span class=\"badge badge-danger\"><i class=\"fas fa-exclamation-triangle\"></i> "+addCommas(rsp.engaged_alerts)+"</span></a>";
		   }

		   if(rsp.alerted_flows > 0) {
			msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/flows_stats.lua?flow_status=alerted\">"
		    msg += "<span class=\"badge badge-danger\">"+addCommas(rsp.alerted_flows)+ " ]] print(i18n("flows")) print[[ <i class=\"fas fa-exclamation-triangle\"></i></span></a>";
		   }
		}

		if((rsp.engaged_alerts > 0 || rsp.has_alerts > 0 || rsp.alerted_flows > 0) && $("#alerts-id").is(":visible") == false) {
		  $("#alerts-id").show();
		}

		if(rsp.ts_alerts && rsp.ts_alerts.influxdb && (!system_view_enabled)) {
		  msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/plugins/influxdb_stats.lua?ifid=]] print(tostring(ifid)) print[[&page=alerts#tab-table-engaged-alerts\">"
		  msg += "<span class=\"badge badge-danger\"><i class=\"fas fa-database\"></i></span></a>";
		}

		var alarm_threshold_low = 60;  /* 60% */
		var alarm_threshold_high = 90; /* 90% */
		var alert = 0;

		if(rsp.num_local_hosts > 0 && (!system_view_enabled)) {
		  msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/hosts_stats.lua?mode=local\">";
		  msg += "<span title=\"]] print(i18n("local_hosts")) print[[\" class=\"badge badge-success\">";
		  msg += addCommas(rsp.num_local_hosts)+" <i class=\"fas fa-laptop\" aria-hidden=\"true\"></i></span></a>";

		  checkMigrationMessage(rsp);
		}

                const num_remote_hosts = rsp.num_hosts - rsp.num_local_hosts;
		if(num_remote_hosts > 0 && !system_view_enabled) {
			msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/hosts_stats.lua?mode=remote\">";
			var remote_hosts_label = "]] print(i18n("remote_hosts")) print[[";

			if (rsp.hosts_pctg < alarm_threshold_low && !system_view_enabled) {
			  msg += "<span title=\"" + remote_hosts_label +"\" class=\"badge badge-secondary\">";
			}
			else if (rsp.hosts_pctg < alarm_threshold_high && !system_view_enabled) {
			  alert = 1;
			  msg += "<span title=\"" + remote_hosts_label +"\" class=\"badge badge-warning\">";
			}
			else {
			  alert = 1;
			  msg += "<span title=\"" + remote_hosts_label +"\" class=\"badge badge-danger\">";
			}

			msg += addCommas(num_remote_hosts)+" <i class=\"fas fa-laptop\" aria-hidden=\"true\"></i></span></a>";
		}

	    if(rsp.num_devices > 0 && !system_view_enabled) {
	    	var macs_label = "]] print(i18n("mac_stats.layer_2_source_devices", {device_type=""})) print[[";
			msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/macs_stats.lua?devices_mode=source_macs_only\">";

			if (rsp.macs_pctg < alarm_threshold_low) {
				msg += "<span title=\"" + macs_label +"\" class=\"badge badge-secondary\">";
			}
			else if(rsp.macs_pctg < alarm_threshold_high) {
				alert = 1;
				msg += "<span title=\"" + macs_label +"\" class=\"badge badge-warning\">";
			}
			else {
				alert = 1;
				msg += "<span title=\"" + macs_label +"\" class=\"badge badge-danger\">";
			}

			msg += addCommas(rsp.num_devices)+" ]] print(i18n("devices")) print[[</span></a>";
	    }

	    if(rsp.num_flows > 0 && !system_view_enabled) {
    		msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/flows_stats.lua\">";

			if (rsp.flows_pctg < alarm_threshold_low) {
				msg += "<span class=\"badge badge-secondary\">";
			}
			else if(rsp.flows_pctg < alarm_threshold_high) {
				alert = 1;
				msg += "<span class=\"badge badge-warning\">";
			}
			else {
				alert = 1;
				msg += "<span class=\"badge badge-danger\">";
			}

			msg += addCommas(rsp.num_flows)+" ]] print(i18n("flows")) print[[ </span> </a>";

			if (rsp.flow_export_drops > 0) {
		   		msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/if_stats.lua\"><span class=\"badge badge-danger\"><i class=\"fas fa-exclamation-triangle\" style=\"color: #FFFFFF;\"></i> "+addCommas(rsp.flow_export_drops)+" Export drop";
		   		if(rsp.flow_export_drops > 1) msg += "s";
				msg += "</span></a>";
			}

	    }

	    if ((rsp.num_live_captures != undefined) && (rsp.num_live_captures > 0) && (!system_view_enabled)) {
			msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/live_capture_stats.lua\">";
			msg += "<span class=\"badge badge-primary\">";
			msg += addCommas(rsp.num_live_captures)+" <i class=\"fas fa-download fa-lg\"></i></span></a>";
	    }

	    if (rsp.remote_assistance != undefined && (!system_view_enabled)) {

	    	var status = rsp.remote_assistance.status;
		  	var status_label = (status == "active") ? "success" : "danger";
	      	msg += "<a href=\"]] print(ntop.getHttpPrefix()) print[[/lua/admin/remote_assistance.lua?tab=status\"><span class=\"badge badge-" + status_label + "\" title=\"]] print(i18n("remote_assistance.remote_assistance")) print[[\">";
	      	msg += "<i class=\"fas fa-comment-dots fa-lg\"></i></span></a>";
	    }

	    if (rsp.traffic_recording != undefined && (!system_view_enabled)) {

			var status_label="primary";
			var status_title="]] print(i18n("traffic_recording.recording")) print [[";

			if (rsp.traffic_recording != "recording") {
				status_label = "danger";
				status_title = "]] print(i18n("traffic_recording.failure")) print [[";
			}

			msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/if_stats.lua?ifid=]] print(tostring(ifid)) print[[&page=traffic_recording&tab=status\">";
			msg += "<span class=\"badge badge-"+status_label+"\" title=\""+addCommas(status_title)+"\">";
			msg += "<i class=\"fas fa-hdd fa-lg\"></i></span></a>";
	    }

	    if (rsp.traffic_extraction != undefined && (!system_view_enabled)) {

			var status_title="]] print(i18n("traffic_recording.traffic_extraction_jobs")) print [[";
			var status_label = "secondary";

			if (rsp.traffic_extraction == "ready") status_label="primary";

			msg += "<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/if_stats.lua?ifid=]] print(tostring(ifid)) print[[&page=traffic_recording&tab=jobs\">";
			msg += "<span class=\"badge badge-"+status_label+"\" title=\""+addCommas(status_title)+"\">";
			msg += rsp.traffic_extraction_num_tasks+" <i class=\"fas fa-tasks fa-lg\"></i></span></a>";
		}

		msg += '</div></li>';
		// append the message inside the network-load element
		const $msg = $(msg);
		// resize element's font size to fit better
		if ($msg.width() > $msg.css('max-width')) {
			$msg.find('span').css('font-size', '0.748rem');
		}

		$('#network-load').html($msg);

	    if (alert) {
			$('#toomany').html("<div class='alert alert-warning'><h4>]] print(i18n("warning")) print[[</h4>]] print(i18n("about.you_have_too_many_flows", {product=info["product"]})) print[[.</div>");
	    }

	  } catch(e) {
	     console.warn(e);
	     /* alert("JSON Error (session expired?): logging out"); window.location.replace("]]print (ntop.getHttpPrefix())print [[/lua/logout.lua");  */
	  }
	}
      });
}

$(document).ajaxError(function(err, response, ajaxSettings, thrownError) {
  if((response.status == 403) && (response.responseText == "Login Required"))
    window.location.href = "]] print(ntop.getHttpPrefix().."/lua/login.lua") print[[";
});

footerRefresh();  /* call immediately to give the UI a more responsive look */
setInterval(footerRefresh, ]]

local footer_refresh_rate = ntop.getPrefs()["housekeeping_frequency"]

print(footer_refresh_rate.."")
print[[ * 1000);  /* re-schedule every [interface-rate] seconds */

//Enable tooltip without a fixer placement
$(document).ready(function () { $("[rel='tooltip']").tooltip(); });
$(document).ready(function () { $("a").tooltip({ 'selector': ''});});
$(document).ready(function () { $("i").tooltip({ 'selector': ''});});

//Automatically open dropdown-menu
$(document).ready(function(){
    $('ul.nav li.dropdown').hover(function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeIn(100);
    }, function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeOut(100);
    });
    $('.collapse')
      .on('shown.bs.collapse', function(){
	$(this).parent().find(".fa-caret-down").removeClass("fa-caret-down").addClass("fa-caret-up");
      })
      .on('hidden.bs.collapse', function(){
	$(this).parent().find(".fa-caret-up").removeClass("fa-caret-up").addClass("fa-caret-down");
    });
});

]]

-- This code rewrites the current page state after a POST request to avoid Document Expired errors
if not table.empty(_POST) then
   print[[
    if ((typeof(history) === "object")
      && (typeof(history).replaceState === "function")
      && (typeof(window.location.href) === "string"))
    history.replaceState(history.state, "", window.location.href);
  ]]
end

print[[

// hide the possibly shown alerts icon in the header
]]
if not _ifstats.isView or ntop.getPrefs().are_alerts_enabled == false then
   print("$('#alerts-li').hide();")
else
   print("$('#alerts-li').show();")
end

print([[
</script>
]])

-- ######################################

if have_nedge then
   print[[<form id="powerOffForm" method="post">
    <input name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" type="hidden" />
    <input name="poweroff" value="" type="hidden" />
  </form>
  <form id="rebootForm" method="post">
    <input name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" type="hidden" />
    <input name="reboot" value="" type="hidden" />
  </form>]]

      print(
	 template.gen("modal_confirm_dialog.html", {
			 dialog={
			    id      = "poweroff_dialog",
			    action  = "$('#powerOffForm').submit()",
			    title   = i18n("nedge.power_off"),
			    message = i18n("nedge.power_off_confirm"),
			    confirm = i18n("nedge.power_off"),
			 }
	 })
      )

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "reboot_dialog",
			 action  = "$('#rebootForm').submit()",
			 title   = i18n("nedge.reboot"),
			 message = i18n("nedge.reboot_corfirm"),
			 confirm = i18n("nedge.reboot"),
		      }
      })
   )
end

-- ######################################

-- close wrapper
print[[
  </div>
  </body>
</html> ]]
