#include <amxmodx>

const MAX_LENGTH = 64;

new Float:Timeout, DemoName[MAX_LENGTH];

public plugin_init() {
	register_plugin("Demo Recorder", "2.4.1", "F@nt0M");
	register_dictionary("demo_recorder.txt");

	bind_pcvar_float(create_cvar(
		.name = "amx_demo_timeout",
		.string = "5.0",
		.has_min = true,
		.min_val = 0.0
	), Timeout);

	hook_cvar_change(create_cvar(
		.name = "amx_demo_format",
		.string = "Demo-%mapname%"
	), "HookChangeFormat");
}

public plugin_cfg() {
	HookChangeFormat(get_cvar_pointer("amx_demo_format"));
}

public HookChangeFormat(const pcvar) {
	get_pcvar_string(pcvar, DemoName, charsmax(DemoName));

	new map[32];
	get_mapname(map, charsmax(map));
	replace(DemoName, charsmax(DemoName), "%mapname%", map);
}

public client_putinserver(id) {
	if (!is_user_bot(id) && !is_user_hltv(id)) {
		if (Timeout > 0.0) {
			set_task(Timeout, "TaskStop", id);
		} else {
			TaskStop(id);
		}
	}
}

public client_disconnected(id) {
	remove_task(id)
}

public TaskStop(id) {
	if (is_user_connected(id)) {
		client_cmd(id, "stop");
		set_task(0.2, "TaskRecord", id);
	}
}

public TaskRecord(const id) {
	if (is_user_connected(id)) {
		client_cmd(id, "record ^"%s^"", DemoName);
		set_task(5.0, "TaskMessage", id);
	}
}

public TaskMessage(const id) {
	if (is_user_connected(id)) {
		new time[10], date[12];

		get_time("%H:%M:%S", time, charsmax(time));
		get_time("%d.%m.%Y", date, charsmax(date));

		client_print_color(id, print_team_default, "%l %l", "DR_TAG", "DR_WARNING", id);
		client_print_color(id, print_team_default, "%l %l", "DR_TAG", "DR_DEMO", DemoName);
		client_print_color(id, print_team_default, "%l %l", "DR_TAG", "DR_TIME", time, date);
	}
}