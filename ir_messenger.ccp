#include <furi.h>
#include <stdlib.h>
#include <stdint.h>

#include <gui/gui.h>
#include <gui/view_dispatcher.h>
#include <gui/modules/text_input.h>

#include <furi_hal_infrared.h>

#define TEXT_BUFFER_SIZE 256
#define MAX_TIMINGS 100

typedef struct {
    ViewDispatcher* view_dispatcher;
    TextInput* text_input;
    char input[TEXT_BUFFER_SIZE];
} AppState;

typedef struct {
    uint32_t* timings;
    int count;
    int index;
} IrTxContext;

// timings -> pointer to raw IR durations
// count   -> total number of timing entries
// index   -> current position while transmitting

static void append_bit_1(uint32_t* timings, int* count) {
    timings[(*count)++] = 560;
    timings[(*count)++] = 1690;
}

static void append_bit_0(uint32_t* timings, int* count) {
    timings[(*count)++] = 560;
    timings[(*count)++] = 560;
}

// Extract bits from a byte in LSB-first order
static void append_byte(uint32_t* timings, int* count, uint8_t value) {
    for(int i = 0; i < 8; i++) {
        uint8_t bit = (value >> i) & 1;

        if(bit == 0) {
            append_bit_0(timings, count);
        } else {
            append_bit_1(timings, count);
        }
    }
}

static FuriHalInfraredTxGetDataState
    ir_tx_get_data(void* context, uint32_t* duration, bool* level) {
    IrTxContext* tx = (IrTxContext*)context;

    if(tx->index < tx->count) {
        *duration = tx->timings[tx->index];
        *level = (tx->index % 2) == 0; // even index = MARK, odd index = SPACE
        tx->index++;
    } else {
        *duration = 0;
        *level = false;
        return FuriHalInfraredTxGetDataStateLastDone;
    }

    if(tx->index == tx->count) {
        return FuriHalInfraredTxGetDataStateLastDone;
    } else {
        return FuriHalInfraredTxGetDataStateOk;
    }
}

// Send one ASCII character as a NEC-like IR frame
static void send_ir_char(uint8_t command) {
    uint32_t timings[MAX_TIMINGS];
    int count = 0;
    uint8_t inverted = ~command;

    // Start pulse
    timings[count++] = 9000;
    timings[count++] = 4500;

    // Address, inverted address, command, inverted command
    append_byte(timings, &count, 0x00);
    append_byte(timings, &count, 0xBF);
    append_byte(timings, &count, command);
    append_byte(timings, &count, inverted);

    // Final NEC mark
    timings[count++] = 560;

    IrTxContext tx = {
        .timings = timings,
        .count = count,
        .index = 0,
    };

    furi_hal_infrared_async_tx_set_data_isr_callback(ir_tx_get_data, &tx);
    furi_hal_infrared_async_tx_start(38000, 0.33f);
    furi_hal_infrared_async_tx_wait_termination();
}

static void text_input_callback(void* ctx) {
    AppState* app = (AppState*)ctx;

    if(app->input[0] == '\0') {
        return;
    }

    for(int i = 0; app->input[i] != '\0'; i++) {
        char c = app->input[i];

        // Convert lowercase to uppercase
        if(c >= 'a' && c <= 'z') {
            c = c - 'a' + 'A';
        }

        send_ir_char((uint8_t)c);
        furi_delay_ms(100);
    }

    // Send end marker
    send_ir_char(0x0A);
    furi_delay_ms(100);
}

// Back button handler
static bool back_event_callback(void* ctx) {
    AppState* app = (AppState*)ctx;
    view_dispatcher_stop(app->view_dispatcher);
    return true;
}

// Matching entry point
extern "C" int32_t sam_app(void* p) {
    UNUSED(p);

    AppState* app = (AppState*)malloc(sizeof(AppState));
    app->view_dispatcher = view_dispatcher_alloc();
    app->text_input = text_input_alloc();
    app->input[0] = '\0';

    text_input_set_result_callback(
        app->text_input,
        text_input_callback,
        app,
        app->input,
        TEXT_BUFFER_SIZE,
        true);

    text_input_set_header_text(app->text_input, "Type & Send");

    Gui* gui = (Gui*)furi_record_open(RECORD_GUI);

    view_dispatcher_add_view(app->view_dispatcher, 0, text_input_get_view(app->text_input));
    view_dispatcher_attach_to_gui(app->view_dispatcher, gui, ViewDispatcherTypeFullscreen);

    view_dispatcher_set_navigation_event_callback(app->view_dispatcher, back_event_callback);
    view_dispatcher_set_event_callback_context(app->view_dispatcher, app);

    view_dispatcher_switch_to_view(app->view_dispatcher, 0);
    view_dispatcher_run(app->view_dispatcher);

    furi_record_close(RECORD_GUI);

    text_input_free(app->text_input);
    view_dispatcher_remove_view(app->view_dispatcher, 0);
    view_dispatcher_free(app->view_dispatcher);
    free(app);

    return 0;
}
