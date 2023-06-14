`define RASTER_NOOP 0
`define RASTER_MAX_SAMPLES 1
`define RASTER_MAX_LINES 2
`define RASTER_SETTLE_TIME 3
`define RASTER_DX 4
`define RASTER_DY 5
`define RASTER_ARM 6
`define RASTER_USED_ADCS 7
`define RASTER_RUNNING 8

`define RASTER_WRITE_BIT (1 << (`RASTER_CMD_WID - 1))

`define RASTER_CMD_WID 8

`define RASTER_DATA_WID 32

/* Instead of using parameters, these values are preprocessor
 * defines so that they may be reference in kernel code.
 */
`define SAMPLEWID 16
`define DAC_DATA_WID 20
`define DAC_WID 24
`define TIMERWID 8
`define ADCNUM 9
`define MAX_ADC_DATA_WID 24
