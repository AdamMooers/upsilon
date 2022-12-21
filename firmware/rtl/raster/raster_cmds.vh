/* Make sure there are no gaps! The code generator will not work
 * correctly.
 */
`define RASTER_NOOP 0
`define RASTER_MAX_SAMPLES 1
`define RASTER_MAX_LINES 2
`define RASTER_SETTLE_TIME 3
`define RASTER_DX 4
`define RASTER_DY 5
`define RASTER_ARM 6
`define RASTER_USED_ADCS 7
`define RASTER_STEPS_PER_SAMPLE 8
`define RASTER_RUNNING 9

`define RASTER_WRITE_BIT (1 << (`RASTER_CMD_WID - 1))

`define RASTER_CMD_WID 8

`define RASTER_DATA_WID 32
