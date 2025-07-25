const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
// override the std panic function with idf.panic
pub const panic = idf.panic;
const log = std.log.scoped(.@"esp-idf");
pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
    // Define logFn to override the std implementation
    .logFn = idf.espLogFn,
};
var global_allocator: ?std.mem.Allocator = null;
const tag = "zig-example";
// Enable pin should be turned on from external source
const MotorLeft:  u8 = 0b00000100;
const MotorRight: u8 = 0b00001000;
const MotorOff:   u8 = 0b00000000;
// portTICK_PERIOD_MS = 10
fn pulse(pin: idf.gpio.Num, delay_ms: u32) !void {
	log.info("PWM: SET", .{});
	try idf.gpio.Level.set(pin, 1);
	idf.vTaskDelay(delay_ms); // for 1/10(portTICK_PERIOD_MS) IDL0 never get CPU(watch dog thinks your core is stuck)->No time for other tasks  
	try idf.gpio.Level.set(pin, 0);
	idf.vTaskDelay(delay_ms);
}
fn writeMotor(control: u8) !void{
	var data = control;
	for (0..8) |_| { // this is runtime control flow
		const bit : u8 = if ((data & 0x80) != 0) 1 else 0; // checks whether MSB of data is set, if that is set bit assigned the value 1 else 0.
		// giving type will infer as runtime else considered as comptime
		try idf.gpio.Level.set(.GPIO_NUM_21, bit); // sending data to seriel pin
		try pulse(.GPIO_NUM_19, 1); // pulsing shift clock pin simultaneously to move the bit in forward at shift reg 
		data <<= 1;
	}
	try pulse(.GPIO_NUM_23, 1); // Pulse LatchPin/RCLK to copy all the data from shift reg --> storage reg.
}
pub fn motions() !void {
	// idf.ESP_LOG(global_allocator.?, tag, "motions() started", .{});
	try idf.gpio.Direction.set(
        .GPIO_NUM_21,			// Serial Pin
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_19,			// Cloak Pin
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_23,			// Latch Pina
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_18,			// Enable Pin
        .GPIO_MODE_OUTPUT,
    );
    
	while (true) {
		try writeMotor(MotorLeft);
		log.info("rotation: CCW", .{});
		idf.vTaskDelay(2000 / idf.portTICK_PERIOD_MS);

		try writeMotor(MotorOff);
		log.info("motor: off", .{});
		idf.vTaskDelay(1000 / idf.portTICK_PERIOD_MS);

		try writeMotor(MotorRight);
		log.info("rotation: CW", .{});
		idf.vTaskDelay(2000 / idf.portTICK_PERIOD_MS);

		try writeMotor(MotorOff);
		log.info("motor: off", .{});
		idf.vTaskDelay(1000 / idf.portTICK_PERIOD_MS);
	}
}
// If your code has a while (true) loop (as in your motor code), make sure to yield the CPU regularly: and so for for loop