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

// constexpr uint8_t SerialPin = 21;
// constexpr uint8_t ClockPin = 19;
// constexpr uint8_t LatchPin = 23;
// constexpr uint8_t EnablePin = 18;
// 74HC595 IC
// const SerialPin = idf.GPIO_NUM_21;	// Data / Seriel Input 	-- (DS) 			-- 8 of l293D	--	Send bits serially (data inputs for shift register) --
// const ClockPin  = idf.GPIO_NUM_19;	// Shift ClockPin		-- (SH_CP/DIR_CLK)	-- 4 of l293D	-- 	Shift the data into register on a rising edge
// const LatchPin  = idf.GPIO_NUM_23;	// Latch ClockPin		-- (ST_IP/DIR_LATCH)-- 12 of l293D 	-- 	Transfer the shifted data into output pins
// const EnablePin = idf.GPIO_NUM_18;	// L293D EN1 / EN2		-- EN1/EN2 			-- 7 of l293D	--	Enables H-Bridge output(can also be used for speed control via PWM) 
// // {
// 	GPIO_NUM_21
// 	GPIO_NUM_19
// 	GPIO_NUM_23
// 	GPIO_NUM_18
// }
// L293D is a dual H-bridge motor driver IC.
// IN1, IN2 - motor A direction control
// IN3, IN4 - motor B direction control
// EN1, EN2 - Enable Pins(PWM speed control On/Off)

// constexpr uint8_t MotorLeft = 0b00000100;
// constexpr uint8_t MotorRight = 0b00001000;
// constexpr uint8_t MotorOff = 0b00000000;

const MotorLeft:  u8 = 0b00000100;
const MotorRight: u8 = 0b00001000;
const MotorOff:   u8 = 0b00000000;

// void pulse(uint8_t pin){
// 	digitalWrite(pin, HIGH);
// 	delay(1);
// 	digitalWrite(pin, LOW);
// 	delay(1);
// }
pub fn init() !void {
	try idf.gpio.Direction.set(
        .GPIO_NUM_21,
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_19,
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_23,
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_18,
        .GPIO_MODE_OUTPUT,
    );
}

fn pulse(pin: u8, delay_ms: u32) !void {
	log.info("PWM: SET", .{});
	try idf.gpio.Level.set(pin, 1);
	idf.vTaskDelay(delay_ms / idf.portTICK_PERIOD_MS);
	try idf.gpio.Level.set(pin, 0);
	idf.vTaskDelay(delay_ms / idf.portTICK_PERIOD_MS);
}

// void writeMotor(uint8_t control){
//   for(uint8_t i = 0; i < 8; ++i){
//     digitalWrite(SerialPin, control & 0x80 ? HIGH : LOW);
//     pulse(ClockPin);
//     control <<= 1;
//   }
//   pulse(LatchPin);  
// }

fn writeMotor(control: u8) !void{
	var data = control;
	for (0..8) |i| {
		const bit = if ((data & 0x80) != 0) 1 else 0; // checks whether MSB of data is set, if that is set bit assigned the value 1 else 0.
		try idf.gpio.Level.set(.GPIO_NUM_21, bit); // sending data to seriel pin
		pulse(.GPIO_NUM_19); // pulsing shift clock pin simultaneously to move the bit in forward at shift reg 
		data <<= 1;
	}  
	// demo ---> Its happening on shift register
	// data			0x80		bit/result		data << 1
	// 10110010 &	10000000	1
	// 01100100 &	10000000 	0
	// 11001000 &	10000000	1
	// 10010000 &	10000000	1
	// 00100000 &	10000000	0
	// 01000000 &	10000000	0
	// 10000000 & 	10000000 	1
	// ------------------------------------------------------
	// After 8 pulses loaded all 8-bits into the shift register.
	// Data is now inside the shift register and not show up on the output pins. 
	// Shift register and the storage register are kept separate on purpose.
	// This allows you to load new data without changing the outputs right away.
	

	try idf.gpio.Level.set(.GPIO_NUM_23, 1); // Pulse LatchPin/RCLK to copy all the data from shift reg --> storage reg.
	// which then updates all the output pins (labeled QA through QH) at the same time. 
	// This simultaneous updating ensures the outputs stay stable while you’re loading the new data.
}


pub fn motions(){
	while (true) {
		writeMotor(MotorLeft);
		// log.info("rotation: CCW", .{});
		idf.vTaskDelay(2000 / idf.portTICK_PERIOD_MS);

		writeMotor(MotorOff);
		// log.info("motor: off", .{});
		idf.vTaskDelay(1000 / idf.portTICK_PERIOD_MS);

		writeMotor(MotorRight);
		// log.info("rotation: CW", .{});
		idf.vTaskDelay(2000 / idf.portTICK_PERIOD_MS);

		// writeMotor(MotorOff);
		log.info("motor: off", .{});
		idf.vTaskDelay(1000 / idf.portTICK_PERIOD_MS);
	}
}

// Error 1:
// error: the following command failed with 1 compilation errors:
// /media/linux/vol1/Docs/NECTAR/Project-code/Zig-esp-idf-full-dev-flow/zig-esp-idf-sample-f8b65b19cb15bb7dcbe5cca638463ead9e8aeafa/build/zig-relsafe-espressif-x86_64-linux-musl-baseline/zig build-lib @/media/linux/vol1/Docs/NECTAR/Project-code/Zig-esp-idf-full-dev-flow/zig-esp-idf-sample-f8b65b19cb15bb7dcbe5cca638463ead9e8aeafa/build/../.zig-cache/args/7d4bac2f871575606e68aca6c8a28a19f123573736f6ce0402334e0b278b7c5c
// Build Summary: 0/3 steps succeeded; 1 failed
// install transitive failure
// └─ install app_zig transitive failure
//    └─ zig build-lib app_zig ReleaseSafe xtensa-freestanding-none 1 errors
// l293d-esp32.zig:12:38: error: expected type expression, found 'invalid token'
// const SerialPin : u8 = .GPIO_NUM_21; // Data / Seriel Input  -- (DS)    -- 8 of l293D -- Send bits serially (data inputs for shift register) --

// --> changed the pin
// Error 2:
//  0/3 steps succeeded; 1 failed
// install transitive failure
// └─ install app_zig transitive failure
//    └─ zig build-lib app_zig ReleaseSafe xtensa-freestanding-none 1 errors
// l293d-esp32.zig:5:41: error: expected type expression, found 'invalid token'
// const log = std.log.scoped(.@"esp-idf");

// -->In the main file, Zig might define a logging scope enum, and that’s what makes .@"esp-idf" valid there.
                                        
//	 what is a scope:
// A log scope is a named label you attach to a logger — like "motor", "wifi", or "esp-idf" — so you can:

// Tag log messages by where they come from

// Control log levels separately for different parts of your app 









// ---
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
const MotorLeft:  u8 = 0b00000100;
const MotorRight: u8 = 0b00001000;
const MotorOff:   u8 = 0b00000000;
pub fn init() !void {
	try idf.gpio.Direction.set(
        .GPIO_NUM_21,
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_19,
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_23,
        .GPIO_MODE_OUTPUT,
    );
    try idf.gpio.Direction.set(
        .GPIO_NUM_18,
        .GPIO_MODE_OUTPUT,
    );
}
fn pulse(pin: u8, delay_ms: u32) !void {
	log.info("PWM: SET", .{});
	try idf.gpio.Level.set(pin, 1);
	idf.vTaskDelay(delay_ms / idf.portTICK_PERIOD_MS);
	try idf.gpio.Level.set(pin, 0);
	idf.vTaskDelay(delay_ms / idf.portTICK_PERIOD_MS);
}
fn writeMotor(control: u8) !void{
	var data = control;
	for (0..8) |_| {
		const bit = if ((data & 0x80) != 0) 1 else 0; // checks whether MSB of data is set, if that is set bit assigned the value 1 else 0.
		try idf.gpio.Level.set(.GPIO_NUM_21, bit); // sending data to seriel pin
		pulse(.GPIO_NUM_19); // pulsing shift clock pin simultaneously to move the bit in forward at shift reg 
		data <<= 1;
	}
	try idf.gpio.Level.set(.GPIO_NUM_23, 1); // Pulse LatchPin/RCLK to copy all the data from shift reg --> storage reg.
}
pub fn motions() !void {
	while (true) {
		writeMotor(MotorLeft);
		// log.info("rotation: CCW", .{});
		idf.vTaskDelay(2000 / idf.portTICK_PERIOD_MS);

		writeMotor(MotorOff);
		// log.info("motor: off", .{});
		idf.vTaskDelay(1000 / idf.portTICK_PERIOD_MS);

		writeMotor(MotorRight);
		// log.info("rotation: CW", .{});
		idf.vTaskDelay(2000 / idf.portTICK_PERIOD_MS);

		// writeMotor(MotorOff);
		log.info("motor: off", .{});
		idf.vTaskDelay(1000 / idf.portTICK_PERIOD_MS);
	}
}