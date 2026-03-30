#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <WiFiClient.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>
#include <SPI.h>

#include <NimBLEDevice.h>

#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <esp_system.h>
#include <esp_wifi.h>
#include <math.h>
#include <algorithm>
#include <vector>

// =====================================================
// ESP32-S3 GATEWAY - NimBLE version, no seq
// - BLE advertising lien tuc cho den khi C3 connect/write
// - Nhan xong packet C3: stop advertising -> disconnect client -> bat WiFi
// - upload -> tat WiFi -> bat lai advertising cho chu ky moi
// =====================================================

// ===================== WIFI CONFIG PORTAL =====================
WiFiManager g_wm;
static const char* WIFI_PORTAL_USER = "admin";
static const char* WIFI_PORTAL_PASS = "123456";
static const char* WIFI_PORTAL_AP_NAME = "ChestGateway";
static const char* WIFI_PORTAL_AP_PASS = "12345678";
static const uint16_t WIFI_PORTAL_TIMEOUT_SEC = 180U;
static bool g_portalLoggedIn = false;
static bool g_wifiCredentialsReady = false;

const char WIFI_LOGIN_PAGE[] PROGMEM = R"rawliteral(
<!doctype html><html lang="vi"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chest Gateway Login</title>
<style>
body{font-family:system-ui;background:#0b1220;color:#e5e7eb;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}
.card{width:min(380px,92vw);background:#111a2e;border:1px solid rgba(148,163,184,.35);border-radius:18px;padding:18px 16px;box-shadow:0 18px 60px rgba(0,0,0,.5)}
input{width:100%;padding:10px 11px;border-radius:12px;border:1px solid rgba(148,163,184,.35);background:#0b1220;color:#e5e7eb;font-size:14px;outline:none;margin-bottom:10px}
button{width:100%;padding:11px;border-radius:999px;border:none;background:linear-gradient(135deg,#3b82f6,#6366f1);color:white;font-weight:700;cursor:pointer}
.err{min-height:16px;margin-top:10px;color:#fb7185;font-size:12px;text-align:center}
</style></head><body>
<div class="card">
<h2>Secure login</h2>
<form method="POST" action="/login">
<input name="user" placeholder="admin" required>
<input name="pass" type="password" placeholder="password" required>
<button type="submit">Continue</button>
</form>
<div class="err">%ERR%</div>
</div></body></html>
)rawliteral";

// ===================== USER CONFIG =====================
static const char* API_BASE_URL = "https://api.eldercare.io.vn";
static const char* DEVICE_ID    = "dev-esp-001";
static const char* DEVICE_TOKEN = "OrdoBN7uZGbL1kzfZOZ5eiY3YA6Pp3ibBr7OA8hcXtk";

static const bool USE_INSECURE_TLS = true;
static const bool ENABLE_ECG_HEART_RATE = false;
static const bool PREFER_ECG_HEART_RATE = false;
static const int ECG_PRIMARY_HR_MIN_QUALITY = 55;
// Must stay aligned with the C3-side reporting threshold, otherwise S3 will
// drop HR/SpO2 even though the BLE packet already contains them.
static const int C3_MIN_VALID_QUALITY = 20;
static const char* DEVICE_TYPE = "chest";
static const char* FIRMWARE_VERSION = "esp32-s3-gateway-nimble-v1";

static const uint32_t C3_PACKET_FRESH_MS      = 60000UL;
static const uint32_t BLE_POST_RX_GUARD_MS    = 250UL;
static const uint32_t BLE_TO_WIFI_GUARD_MS    = 1200UL;
static const uint32_t WIFI_CONNECT_TIMEOUT_MS = 15000UL;
static const uint32_t HTTP_TIMEOUT_MS         = 15000UL;
static const uint8_t HTTP_RETRY_COUNT         = 2U;
static const uint32_t HTTP_RETRY_BACKOFF_MS   = 600UL;
static const uint32_t NTP_RETRY_MS            = 30000UL;
// Skin/chest-mounted probes can legitimately read below 30C, especially before
// thermal stabilization, so keep the upload gate loose enough to retain them.
static const float BODY_TEMP_UPLOAD_MIN_C     = 25.0f;
static const float BODY_TEMP_UPLOAD_MAX_C     = 43.5f;

static const uint32_t SENSOR_TASK_PERIOD_MS   = 4UL;   // 250Hz
static const uint32_t MPU_SAMPLE_INTERVAL_MS  = 20UL;  // 50Hz
static const size_t ECG_WAVEFORM_SAMPLES      = 250U;  // 1 second at 250Hz
static const uint8_t ECG_RR_HISTORY_SIZE      = 8U;
static const bool ECG_USE_LEAD_OFF_PINS       = false;
static const uint32_t ECG_LEAD_DEBOUNCE_MS    = 120UL;
static const uint32_t ECG_REFACTORY_MS        = 250UL;
static const uint32_t ECG_RR_MIN_MS           = 333UL;
static const uint32_t ECG_RR_MAX_MS           = 1714UL;
static const uint32_t ECG_HR_HOLD_MS          = 6000UL;
static const uint32_t ECG_CONNECT_STABLE_MS   = 600UL;
static const uint32_t ECG_SIGNAL_INVALID_MS   = 4000UL;
static const uint32_t ECG_SIGNAL_INVALID_HR_GRACE_MS = 8000UL;
static const uint8_t ECG_MIN_STABLE_BEATS     = 3U;
static const uint8_t ECG_OVERSAMPLE_COUNT     = 12U;
static const float ECG_DC_ALPHA               = 0.008f;
static const float ECG_BAND_ALPHA             = 0.14f;
static const float ECG_ENVELOPE_ALPHA         = 0.025f;
static const float ECG_THRESHOLD_SCALE        = 1.45f;
static const float ECG_THRESHOLD_MIN          = 16.0f;
static const float ECG_RELEASE_RATIO          = 0.60f;
static const float ECG_MOTION_THRESHOLD_BOOST = 0.35f;
static const int ECG_ADC_VALID_MIN            = 128;
static const int ECG_ADC_VALID_MAX            = 3968;
static const float ECG_CONTACT_ENVELOPE_MIN   = 1.6f;
static const float ECG_CONTACT_ENVELOPE_MAX   = 420.0f;
static const float ECG_CONTACT_ENVELOPE_HOLD_MIN = 0.8f;
static const float ECG_CONTACT_ENVELOPE_HOLD_MAX = 520.0f;
static const float ECG_DISPLAY_BASELINE_ALPHA = 0.0035f;
static const float ECG_DISPLAY_SMOOTH_ALPHA   = 0.18f;
static const float ECG_DISPLAY_ENVELOPE_ALPHA = 0.020f;
static const float ECG_DISPLAY_GAIN_SCALE     = 1.8f;
static const float ECG_DISPLAY_GAIN_MIN       = 24.0f;
static const uint32_t ECG_MAX_RR_MEAN_ABS_DEV_MS = 90UL;
static const uint32_t ECG_MAX_RR_SPAN_MS      = 180UL;
static const int ECG_MAX_HR_STEP_BPM          = 18;
static const float ECG_HR_SMOOTHING_ALPHA     = 0.35f;
static const float GRAVITY_MPS2               = 9.80665f;
static const float FALL_FREE_FALL_G           = 0.96f;
static const float FALL_GYRO_TRIGGER_DPS      = 95.0f;
static const float FALL_TILT_TRIGGER_DEG      = 28.0f;
static const float FALL_TILT_RATE_TRIGGER_DPS = 40.0f;
static const float FALL_IMPACT_G              = 1.75f;
static const float FALL_POSTURE_DEG           = 42.0f;
static const float FALL_POST_LINEAR_G         = 0.45f;
static const float FALL_POST_GYRO_DPS         = 45.0f;
static const uint32_t FALL_ROTATION_WINDOW_MS = 1000UL;
static const uint32_t FALL_IMPACT_WINDOW_MS   = 1800UL;
static const uint32_t FALL_REST_WINDOW_MS     = 900UL;
static const uint32_t FALL_RECOVERY_WINDOW_MS = 5000UL;
static const uint32_t FALL_EVENT_HOLD_MS      = 10000UL;

// ===================== PIN MAP =====================
static const int MPU_SCL_PIN = 13;
static const int MPU_SDA_PIN = 12;

static const int TFT_SCLK_PIN = 5;
static const int TFT_MOSI_PIN = 6;
static const int TFT_RST_PIN  = 7;
static const int TFT_DC_PIN   = 4;
static const int TFT_CS_PIN   = 3;

static const int AD8232_SDN_PIN      = 8;
static const int AD8232_LO_PLUS_PIN  = 9;
static const int AD8232_LO_MINUS_PIN = 10;
static const int AD8232_OUT_PIN      = 11;

// ===================== BLE CONFIG =====================
static const char* BLE_DEVICE_NAME  = "Eldercare-ESP32";
static const char* BLE_SERVICE_UUID = "12345678-1234-1234-1234-1234567890ab";
static const char* BLE_WRITE_UUID   = "12345678-1234-1234-1234-1234567890ad";

// ===================== TYPES =====================
struct C3Packet {
  int hr = 0;
  int spo2 = 0;
  float temp = NAN;
  int q = 0;
  bool sim = false;
  uint32_t lastUpdateMs = 0;
  bool valid = false;
};

struct Snapshot {
  int hr = 0;
  int hrBle = 0;
  int hrEcg = 0;
  int spo2 = 0;
  float temp = NAN;
  int respiratoryRate = 0;
  bool fallDetected = false;
  uint8_t fallPhase = 0;
  bool ecgLeadOff = true;
  int ecgQuality = 0;
  bool c3Available = false;
  bool c3Fresh = false;
  bool c3Sim = false;
  int c3Quality = 0;
  float ecgWaveform[ECG_WAVEFORM_SAMPLES] = {0.0f};
};

enum AppState : uint8_t {
  STATE_BLE_ACTIVE = 0,
  STATE_BLE_STOP,
  STATE_WIFI_START,
  STATE_WIFI_WAIT,
  STATE_SEND,
  STATE_CLEANUP
};

enum UploadReason : uint8_t {
  UPLOAD_REASON_NONE = 0,
  UPLOAD_REASON_ROUTINE,
  UPLOAD_REASON_FALL_ALERT
};

enum FallPhase : uint8_t {
  FALL_PHASE_IDLE = 0,
  FALL_PHASE_FREE_FALL,
  FALL_PHASE_ROTATION,
  FALL_PHASE_POST_IMPACT,
  FALL_PHASE_CONFIRMED
};

struct FallDetectorContext {
  FallPhase phase = FALL_PHASE_IDLE;
  bool refValid = false;
  bool sawGyroBurst = false;
  bool sawTiltChange = false;
  float gravX = 0.0f;
  float gravY = 0.0f;
  float gravZ = GRAVITY_MPS2;
  float refX = 0.0f;
  float refY = 0.0f;
  float refZ = 1.0f;
  float lastTiltDeg = 0.0f;
  float lastAccelMagG = 1.0f;
  float lastGyroMagDps = 0.0f;
  float lastImpactMagG = 0.0f;
  uint32_t phaseStartedMs = 0;
  uint32_t impactMs = 0;
  uint32_t restStartedMs = 0;
  uint32_t confirmedUntilMs = 0;
  uint32_t lastSampleMs = 0;
};

// ===================== GLOBALS =====================
Adafruit_MPU6050 mpu;
SPIClass tftSpi(FSPI);
Adafruit_ST7735 tft(&tftSpi, TFT_CS_PIN, TFT_DC_PIN, TFT_RST_PIN);

static AppState g_state = STATE_BLE_ACTIVE;
static uint32_t g_stateStartedMs = 0;
static uint32_t g_guardUntilMs = 0;
static uint32_t g_lastBleStatusLogMs = 0;
static uint32_t g_lastHealthLogMs = 0;
static uint32_t g_lastNtpAttemptMs = 0;
static uint32_t g_lastDisplayRefreshMs = 0;
static bool g_timeSynced = false;
static bool g_displayPrimed = false;

// BLE globals
static NimBLEServer* g_bleServer = nullptr;
static NimBLEAdvertising* g_bleAdvertising = nullptr;
static NimBLECharacteristic* g_bleWriteChar = nullptr;
static bool g_bleInitialized = false;
static bool g_bleAdvertisingOn = false;
static bool g_bleWindowOpen = false;
static bool g_bleClientConnected = false;
static bool g_bleSawConnection = false;
static bool g_c3PacketReceivedThisCycle = false;
static uint32_t g_lastC3PacketRxMs = 0;
static uint32_t g_bleConnectCount = 0;
static uint16_t g_bleConnHandle = 0xFFFF;

// sensor globals
static TaskHandle_t g_sensorTaskHandle = nullptr;
static portMUX_TYPE g_sensorMux = portMUX_INITIALIZER_UNLOCKED;
static portMUX_TYPE g_c3Mux = portMUX_INITIALIZER_UNLOCKED;

static int g_latestEcgRaw = 0;
static bool g_latestLeadOff = true;
static int g_ecgDerivedHeartRate = 0;
static int g_ecgQualityPct = 0;
static bool g_fallDetected = false;
static FallPhase g_fallPhase = FALL_PHASE_IDLE;
static bool g_fallAlertPending = false;
static FallPhase g_fallAlertPhase = FALL_PHASE_IDLE;
static uint32_t g_lastFallAlertMs = 0;
static UploadReason g_uploadReason = UPLOAD_REASON_NONE;
static float g_ecgWaveform[ECG_WAVEFORM_SAMPLES] = {0.0f};
static size_t g_ecgWaveformHead = 0;
static bool g_ecgWaveformFilled = false;
static bool g_mpuReady = false;

static C3Packet g_latestC3;

// ===================== HELPERS =====================
const char* resetReasonText(esp_reset_reason_t reason) {
  switch (reason) {
    case ESP_RST_UNKNOWN: return "unknown";
    case ESP_RST_POWERON: return "power on";
    case ESP_RST_EXT: return "external pin";
    case ESP_RST_SW: return "software reset";
    case ESP_RST_PANIC: return "panic/exception";
    case ESP_RST_INT_WDT: return "interrupt watchdog";
    case ESP_RST_TASK_WDT: return "task watchdog";
    case ESP_RST_WDT: return "other watchdog";
    case ESP_RST_DEEPSLEEP: return "deep sleep";
    case ESP_RST_BROWNOUT: return "brownout";
    case ESP_RST_SDIO: return "sdio";
    default: return "other";
  }
}

void printResetReason() {
  esp_reset_reason_t reason = esp_reset_reason();
  Serial.printf("[BOOT] reset reason=%d (%s)\n", (int)reason, resetReasonText(reason));
}

double nowEpochSeconds() {
  struct timeval tv;
  if (gettimeofday(&tv, nullptr) == 0 && tv.tv_sec > 1700000000) {
    return (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
  }
  return (double)millis() / 1000.0;
}

bool hasValidRtcTime() {
  struct timeval tv;
  return (gettimeofday(&tv, nullptr) == 0 && tv.tv_sec > 1700000000);
}

uint32_t medianU32(const uint32_t* values, size_t count) {
  if (count == 0) return 0;
  uint32_t scratch[8] = {0};
  size_t n = count > 8 ? 8 : count;
  for (size_t i = 0; i < n; ++i) scratch[i] = values[i];
  std::sort(scratch, scratch + n);
  if (n % 2 == 1) return scratch[n / 2];
  return (scratch[(n / 2) - 1] + scratch[n / 2]) / 2U;
}

uint32_t spanU32(const uint32_t* values, size_t count) {
  if (count == 0) return 0;

  uint32_t minValue = values[0];
  uint32_t maxValue = values[0];
  for (size_t i = 1; i < count; ++i) {
    if (values[i] < minValue) minValue = values[i];
    if (values[i] > maxValue) maxValue = values[i];
  }
  return maxValue - minValue;
}

float meanAbsDeviationU32(const uint32_t* values, size_t count, uint32_t center) {
  if (count == 0) return 0.0f;

  float total = 0.0f;
  for (size_t i = 0; i < count; ++i) {
    total += fabsf((float)values[i] - (float)center);
  }
  return total / (float)count;
}

bool rrWindowStable(const uint32_t* values, size_t count, uint32_t& medianOut) {
  if (count < ECG_MIN_STABLE_BEATS) {
    return false;
  }

  medianOut = medianU32(values, count);
  const float meanAbsDev = meanAbsDeviationU32(values, count, medianOut);
  const uint32_t span = spanU32(values, count);

  return meanAbsDev <= (float)ECG_MAX_RR_MEAN_ABS_DEV_MS &&
         span <= ECG_MAX_RR_SPAN_MS;
}

void changeState(AppState s) {
  g_state = s;
  g_stateStartedMs = millis();
}

const char* ecgQualityText(int qualityPct, bool leadOff) {
  if (leadOff) return "poor";
  if (qualityPct >= 70) return "good";
  if (qualityPct >= 40) return "fair";
  return "poor";
}

const char* stateText(AppState s) {
  switch (s) {
    case STATE_BLE_ACTIVE: return "BLE";
    case STATE_BLE_STOP: return "BLE_STOP";
    case STATE_WIFI_START: return "WIFI_ON";
    case STATE_WIFI_WAIT: return "WIFI_WAIT";
    case STATE_SEND: return "UPLOAD";
    case STATE_CLEANUP: return "CLEANUP";
    default: return "?";
  }
}

const char* fallPhaseText(FallPhase phase) {
  switch (phase) {
    case FALL_PHASE_IDLE: return "IDLE";
    case FALL_PHASE_FREE_FALL: return "FREE_FALL";
    case FALL_PHASE_ROTATION: return "ROTATION";
    case FALL_PHASE_POST_IMPACT: return "POST_IMPACT";
    case FALL_PHASE_CONFIRMED: return "CONFIRMED";
    default: return "?";
  }
}

const char* uploadReasonText(UploadReason reason) {
  switch (reason) {
    case UPLOAD_REASON_ROUTINE: return "routine";
    case UPLOAD_REASON_FALL_ALERT: return "fall_alert";
    case UPLOAD_REASON_NONE:
    default:
      return "none";
  }
}

float clampUnit(float value) {
  if (value > 1.0f) return 1.0f;
  if (value < -1.0f) return -1.0f;
  return value;
}

bool hasDisplayTemperature(float value) {
  return !isnan(value);
}

bool shouldUploadBodyTemperature(float value) {
  return hasDisplayTemperature(value) &&
         value >= BODY_TEMP_UPLOAD_MIN_C &&
         value <= BODY_TEMP_UPLOAD_MAX_C;
}

bool i2cDevicePresent(TwoWire& bus, uint8_t address) {
  bus.beginTransmission(address);
  return bus.endTransmission() == 0;
}

void logI2CBusDevices(TwoWire& bus) {
  bool foundAny = false;
  Serial.printf("[I2C] scanning SDA=%d SCL=%d\n", MPU_SDA_PIN, MPU_SCL_PIN);
  for (uint8_t address = 0x08; address <= 0x77; ++address) {
    if (!i2cDevicePresent(bus, address)) continue;
    foundAny = true;
    Serial.printf("[I2C] found device at 0x%02X\n", address);
  }

  if (!foundAny) {
    Serial.println("[I2C] no device found");
  }
}

float vectorMagnitude(float x, float y, float z) {
  return sqrtf((x * x) + (y * y) + (z * z));
}

void normalizeVector(float& x, float& y, float& z) {
  float mag = vectorMagnitude(x, y, z);
  if (mag <= 0.0001f) return;
  x /= mag;
  y /= mag;
  z /= mag;
}

void resetFallDetectorPhase(FallDetectorContext& ctx) {
  ctx.phase = FALL_PHASE_IDLE;
  ctx.sawGyroBurst = false;
  ctx.sawTiltChange = false;
  ctx.phaseStartedMs = 0;
  ctx.impactMs = 0;
  ctx.restStartedMs = 0;
  ctx.confirmedUntilMs = 0;
  ctx.lastImpactMagG = 0.0f;
}

bool updateFallDetection(const sensors_event_t& accelEvt,
                         const sensors_event_t& gyroEvt,
                         uint32_t nowMs,
                         float& motionLocal,
                         FallPhase& phaseOut,
                         float& accelMagGOut,
                         float& gyroMagDpsOut,
                         float& tiltDegOut,
                         float& impactMagGOut) {
  static FallDetectorContext ctx;

  const float ax = accelEvt.acceleration.x;
  const float ay = accelEvt.acceleration.y;
  const float az = accelEvt.acceleration.z;

  const float gx = gyroEvt.gyro.x * (180.0f / PI);
  const float gy = gyroEvt.gyro.y * (180.0f / PI);
  const float gz = gyroEvt.gyro.z * (180.0f / PI);

  const float accelMagMps2 = vectorMagnitude(ax, ay, az);
  const float accelMagG = accelMagMps2 / GRAVITY_MPS2;
  const float gyroMagDps = vectorMagnitude(gx, gy, gz);

  ctx.gravX += 0.10f * (ax - ctx.gravX);
  ctx.gravY += 0.10f * (ay - ctx.gravY);
  ctx.gravZ += 0.10f * (az - ctx.gravZ);

  const float linX = ax - ctx.gravX;
  const float linY = ay - ctx.gravY;
  const float linZ = az - ctx.gravZ;
  const float linearMagMps2 = vectorMagnitude(linX, linY, linZ);
  const float linearMagG = linearMagMps2 / GRAVITY_MPS2;

  motionLocal += 0.15f * (linearMagMps2 - motionLocal);

  float gravNX = ctx.gravX;
  float gravNY = ctx.gravY;
  float gravNZ = ctx.gravZ;
  normalizeVector(gravNX, gravNY, gravNZ);

  if (!ctx.refValid && vectorMagnitude(ctx.gravX, ctx.gravY, ctx.gravZ) > (0.4f * GRAVITY_MPS2)) {
    ctx.refX = gravNX;
    ctx.refY = gravNY;
    ctx.refZ = gravNZ;
    ctx.refValid = true;
  }

  const bool stableForReference =
    ctx.phase == FALL_PHASE_IDLE &&
    fabsf(accelMagG - 1.0f) <= 0.15f &&
    linearMagG <= 0.12f &&
    gyroMagDps <= 20.0f;

  if (ctx.refValid && stableForReference) {
    ctx.refX += 0.01f * (gravNX - ctx.refX);
    ctx.refY += 0.01f * (gravNY - ctx.refY);
    ctx.refZ += 0.01f * (gravNZ - ctx.refZ);
    normalizeVector(ctx.refX, ctx.refY, ctx.refZ);
  }

  float tiltDeg = ctx.lastTiltDeg;
  if (ctx.refValid) {
    const float dot = clampUnit((gravNX * ctx.refX) + (gravNY * ctx.refY) + (gravNZ * ctx.refZ));
    tiltDeg = acosf(dot) * (180.0f / PI);
  }

  const uint32_t dtMs = (ctx.lastSampleMs == 0 || nowMs <= ctx.lastSampleMs)
    ? MPU_SAMPLE_INTERVAL_MS
    : (nowMs - ctx.lastSampleMs);
  const float tiltRateDps = fabsf(tiltDeg - ctx.lastTiltDeg) * (1000.0f / (float)dtMs);

  ctx.lastSampleMs = nowMs;
  ctx.lastTiltDeg = tiltDeg;
  ctx.lastAccelMagG = accelMagG;
  ctx.lastGyroMagDps = gyroMagDps;

  switch (ctx.phase) {
    case FALL_PHASE_IDLE:
      if (accelMagG <= FALL_FREE_FALL_G) {
        ctx.phase = FALL_PHASE_FREE_FALL;
        ctx.phaseStartedMs = nowMs;
        ctx.sawGyroBurst = false;
        ctx.sawTiltChange = false;
        ctx.lastImpactMagG = 0.0f;
      }
      break;

    case FALL_PHASE_FREE_FALL:
      if (gyroMagDps >= FALL_GYRO_TRIGGER_DPS) {
        ctx.sawGyroBurst = true;
      }
      if (tiltDeg >= FALL_TILT_TRIGGER_DEG || tiltRateDps >= FALL_TILT_RATE_TRIGGER_DPS) {
        ctx.sawTiltChange = true;
      }
      if (accelMagG > ctx.lastImpactMagG) {
        ctx.lastImpactMagG = accelMagG;
      }
      if (accelMagG >= FALL_IMPACT_G && (ctx.sawGyroBurst || ctx.sawTiltChange)) {
        ctx.phase = FALL_PHASE_POST_IMPACT;
        ctx.impactMs = nowMs;
        ctx.restStartedMs = 0;
      } else if (ctx.sawGyroBurst || ctx.sawTiltChange) {
        ctx.phase = FALL_PHASE_ROTATION;
        ctx.phaseStartedMs = nowMs;
      } else if ((nowMs - ctx.phaseStartedMs) > FALL_ROTATION_WINDOW_MS) {
        resetFallDetectorPhase(ctx);
      }
      break;

    case FALL_PHASE_ROTATION:
      if (accelMagG > ctx.lastImpactMagG) {
        ctx.lastImpactMagG = accelMagG;
      }
      if (accelMagG >= FALL_IMPACT_G) {
        ctx.phase = FALL_PHASE_POST_IMPACT;
        ctx.impactMs = nowMs;
        ctx.restStartedMs = 0;
      } else if ((nowMs - ctx.phaseStartedMs) > FALL_IMPACT_WINDOW_MS) {
        resetFallDetectorPhase(ctx);
      }
      break;

    case FALL_PHASE_POST_IMPACT: {
      if (accelMagG > ctx.lastImpactMagG) {
        ctx.lastImpactMagG = accelMagG;
      }

      const bool lyingPosture = tiltDeg >= FALL_POSTURE_DEG;
      const bool lowMotion = linearMagG <= FALL_POST_LINEAR_G && gyroMagDps <= FALL_POST_GYRO_DPS;

      if (lyingPosture && lowMotion) {
        if (ctx.restStartedMs == 0) {
          ctx.restStartedMs = nowMs;
        } else if ((nowMs - ctx.restStartedMs) >= FALL_REST_WINDOW_MS) {
          ctx.phase = FALL_PHASE_CONFIRMED;
          ctx.confirmedUntilMs = nowMs + FALL_EVENT_HOLD_MS;
        }
      } else {
        ctx.restStartedMs = 0;
      }

      if ((nowMs - ctx.impactMs) > FALL_RECOVERY_WINDOW_MS) {
        resetFallDetectorPhase(ctx);
      }
      break;
    }

    case FALL_PHASE_CONFIRMED:
      if ((int32_t)(nowMs - ctx.confirmedUntilMs) >= 0) {
        resetFallDetectorPhase(ctx);
      }
      break;

    default:
      resetFallDetectorPhase(ctx);
      break;
  }

  phaseOut = ctx.phase;
  accelMagGOut = ctx.lastAccelMagG;
  gyroMagDpsOut = ctx.lastGyroMagDps;
  tiltDegOut = ctx.lastTiltDeg;
  impactMagGOut = ctx.lastImpactMagG;
  return ctx.phase == FALL_PHASE_CONFIRMED;
}

void latchFallAlert(FallPhase phase, uint32_t nowMs) {
  portENTER_CRITICAL(&g_sensorMux);
  g_fallAlertPending = true;
  g_fallAlertPhase = phase;
  g_lastFallAlertMs = nowMs;
  portEXIT_CRITICAL(&g_sensorMux);
}

void clearFallAlert() {
  portENTER_CRITICAL(&g_sensorMux);
  g_fallAlertPending = false;
  g_fallAlertPhase = FALL_PHASE_IDLE;
  portEXIT_CRITICAL(&g_sensorMux);
}

// ===================== TFT =====================
uint16_t rgb565(uint8_t r, uint8_t g, uint8_t b) {
  return (uint16_t)(((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3));
}

uint16_t stateColor(AppState s) {
  switch (s) {
    case STATE_BLE_ACTIVE: return rgb565(52, 211, 153);
    case STATE_BLE_STOP: return rgb565(251, 191, 36);
    case STATE_WIFI_START: return rgb565(56, 189, 248);
    case STATE_WIFI_WAIT: return rgb565(59, 130, 246);
    case STATE_SEND: return rgb565(248, 113, 113);
    case STATE_CLEANUP: return rgb565(168, 85, 247);
    default: return rgb565(148, 163, 184);
  }
}

uint16_t ecgQualityColor(int qualityPct, bool leadOff) {
  if (leadOff) return rgb565(248, 113, 113);
  if (qualityPct >= 70) return rgb565(52, 211, 153);
  if (qualityPct >= 40) return rgb565(251, 191, 36);
  return rgb565(248, 113, 113);
}

static const char* UI_NO_DATA_TEXT = "CHUA CO";

String valueOrDash(int value, bool valid) {
  return valid ? String(value) : "--";
}

String floatOrDash(float value, uint8_t decimals) {
  return isnan(value) ? "--" : String(value, (unsigned int)decimals);
}

String valueOrText(int value, bool valid, const char* emptyText) {
  return valid ? String(value) : String(emptyText);
}

String floatOrText(float value, uint8_t decimals, const char* emptyText) {
  return isnan(value) ? String(emptyText) : String(value, (unsigned int)decimals);
}

void drawPanel(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t fill, uint16_t border) {
  tft.fillRoundRect(x, y, w, h, 6, fill);
  tft.drawRoundRect(x, y, w, h, 6, border);
}

void drawTag(int16_t x, int16_t y, const String& text, uint16_t fill, uint16_t textColor) {
  int16_t w = (int16_t)(text.length() * 6) + 12;
  tft.fillRoundRect(x, y, w, 12, 6, fill);
  tft.setTextSize(1);
  tft.setTextColor(textColor, fill);
  tft.setCursor(x + 6, y + 2);
  tft.print(text);
}

void drawStatusTile(int16_t x,
                    int16_t y,
                    int16_t w,
                    const char* label,
                    const char* value,
                    uint16_t accent,
                    uint16_t bg,
                    uint16_t border) {
  uint16_t muted = rgb565(148, 163, 184);
  uint16_t bright = rgb565(226, 232, 240);
  int16_t valueX = x + w - ((int16_t)strlen(value) * 6) - 8;
  if (valueX < x + 38) valueX = x + 38;

  drawPanel(x, y, w, 18, bg, border);
  tft.fillCircle(x + 10, y + 9, 3, accent);
  tft.setTextSize(1);
  tft.setTextColor(muted, bg);
  tft.setCursor(x + 18, y + 6);
  tft.print(label);

  tft.setTextColor(bright, bg);
  tft.setCursor(valueX, y + 6);
  tft.print(value);
}

void drawMetricCard(int16_t x,
                    int16_t y,
                    int16_t w,
                    int16_t h,
                    const char* label,
                    const String& value,
                    const char* unit,
                    uint16_t accent,
                    uint16_t bg,
                    uint16_t border) {
  uint16_t muted = rgb565(148, 163, 184);
  int16_t valueX = x + 6;
  int16_t valueY = y + 14;
  drawPanel(x, y, w, h, bg, border);

  tft.setTextSize(1);
  tft.setTextColor(muted, bg);
  tft.setCursor(x + 6, y + 4);
  tft.print(label);

  if (unit != nullptr && unit[0] != '\0') {
    int16_t unitX = x + w - ((int16_t)strlen(unit) * 6) - 6;
    tft.setCursor(unitX, y + 4);
    tft.print(unit);
  }

  tft.setTextSize(1);
  tft.setTextColor(accent, bg);
  tft.setCursor(valueX, valueY);
  tft.print(value);
}

void drawWaveformPanel(const Snapshot& s) {
  uint16_t panelBg = rgb565(12, 19, 31);
  uint16_t grid = rgb565(30, 41, 59);
  uint16_t quality = ecgQualityColor(s.ecgQuality, s.ecgLeadOff);
  uint16_t accent = rgb565(250, 204, 21);
  const char* qualityText = ecgQualityText(s.ecgQuality, s.ecgLeadOff);
  const char* leadText = s.ecgLeadOff ? "LEAD OFF" : "LEAD OK";
  int16_t x = 4;
  int16_t y = 82;
  int16_t w = 152;
  int16_t h = 42;
  String ecgHrText = ENABLE_ECG_HEART_RATE
    ? valueOrText(s.hrEcg, s.hrEcg > 0, UI_NO_DATA_TEXT)
    : String("TAT");
  int16_t graphX = x + 6;
  int16_t graphY = y + 16;
  int16_t graphW = w - 12;
  int16_t graphH = 18;
  int16_t midY = graphY + (graphH / 2);

  drawPanel(x, y, w, h, panelBg, quality);

  tft.setTextSize(1);
  tft.setTextColor(rgb565(148, 163, 184), panelBg);
  tft.setCursor(x + 6, y + 4);
  tft.print("DIEN TAM DO");

  drawTag(x + 112, y + 3, String(qualityText), quality, rgb565(10, 15, 26));

  tft.drawFastHLine(graphX, midY, graphW, grid);
  tft.drawFastHLine(graphX, graphY + graphH, graphW, grid);

  if (s.ecgLeadOff) {
    tft.setTextColor(rgb565(248, 113, 113), panelBg);
    tft.setCursor(x + 48, y + 24);
    tft.print("lead off");
  } else {
    float limit = 0.9f;
    int16_t prevX = graphX;
    float sample0 = s.ecgWaveform[0];
    if (sample0 > limit) sample0 = limit;
    if (sample0 < -limit) sample0 = -limit;
    int16_t prevY = midY - (int16_t)(sample0 * ((float)graphH * 0.5f));

    for (size_t i = 1; i < ECG_WAVEFORM_SAMPLES; ++i) {
      float sample = s.ecgWaveform[i];
      if (sample > limit) sample = limit;
      if (sample < -limit) sample = -limit;

      int16_t px = graphX + (int16_t)(((int32_t)i * (graphW - 1)) / (ECG_WAVEFORM_SAMPLES - 1));
      int16_t py = midY - (int16_t)(sample * ((float)graphH * 0.5f));
      tft.drawLine(prevX, prevY, px, py, rgb565(125, 211, 252));
      prevX = px;
      prevY = py;
    }
  }

  tft.setTextColor(rgb565(203, 213, 225), panelBg);
  tft.setCursor(x + 6, y + 34);
  tft.print("HR ");
  tft.print(ecgHrText);
  if (ENABLE_ECG_HEART_RATE) {
    tft.print(" BPM");
  }
  tft.setCursor(x + w - ((int16_t)strlen(leadText) * 6) - 8, y + 34);
  tft.print(leadText);
}

void initDisplay() {
  tftSpi.begin(TFT_SCLK_PIN, -1, TFT_MOSI_PIN, TFT_CS_PIN);
  tft.initR(INITR_BLACKTAB);
  tft.setRotation(1);
  tft.fillScreen(rgb565(6, 11, 20));
  tft.setTextWrap(false);
  tft.setTextSize(1);
  tft.setTextColor(rgb565(226, 232, 240), rgb565(6, 11, 20));
  tft.setCursor(10, 50);
  tft.println("Eldercare");
  tft.setCursor(10, 64);
  tft.setTextColor(rgb565(96, 165, 250), rgb565(6, 11, 20));
  tft.println("Gateway ready");
  g_displayPrimed = false;
}

void refreshDisplay() {
  Snapshot s = captureSnapshot();
  bool includeC3Vitals = s.c3Fresh && s.c3Quality >= C3_MIN_VALID_QUALITY;
  bool includeTemp = s.c3Fresh && hasDisplayTemperature(s.temp);
  uint16_t screenBg = rgb565(6, 11, 20);
  uint16_t cardBg = rgb565(15, 23, 36);
  uint16_t cardBorder = rgb565(34, 52, 72);
  uint16_t bleColor = g_bleClientConnected ? rgb565(52, 211, 153) : rgb565(251, 191, 36);
  uint16_t wifiColor = WiFi.status() == WL_CONNECTED ? rgb565(56, 189, 248) : rgb565(100, 116, 139);

  // Avoid full-screen clears on every refresh; the widgets repaint their own bounds.
  if (!g_displayPrimed) {
    tft.fillScreen(screenBg);
    g_displayPrimed = true;
  }

  drawStatusTile(4, 4, 74, "BLE", g_bleClientConnected ? "ON" : "WAIT", bleColor, cardBg, cardBorder);
  drawStatusTile(82, 4, 74, "WIFI", WiFi.status() == WL_CONNECTED ? "ON" : "OFF", wifiColor, cardBg, cardBorder);

  drawMetricCard(4, 26, 74, 24, "HR", valueOrText(s.hr, s.hr > 0, UI_NO_DATA_TEXT), "bpm", rgb565(74, 222, 128), cardBg, cardBorder);
  drawMetricCard(82, 26, 74, 24, "SpO2", valueOrText(s.spo2, includeC3Vitals && s.spo2 > 0, UI_NO_DATA_TEXT), "%", includeC3Vitals ? rgb565(56, 189, 248) : rgb565(100, 116, 139), cardBg, cardBorder);
  drawMetricCard(4, 54, 74, 24, "TEMP", floatOrText(includeTemp ? s.temp : NAN, 1, UI_NO_DATA_TEXT), "C", includeTemp ? rgb565(251, 113, 133) : rgb565(100, 116, 139), cardBg, cardBorder);
  drawMetricCard(82, 54, 74, 24, "FALL", s.fallDetected ? "YES" : "NO", "", s.fallDetected ? rgb565(248, 113, 113) : rgb565(74, 222, 128), cardBg, cardBorder);

  drawWaveformPanel(s);
}

// ===================== LOCAL SENSOR =====================
void initAd8232() {
  pinMode(AD8232_SDN_PIN, OUTPUT);
  digitalWrite(AD8232_SDN_PIN, HIGH);

  pinMode(AD8232_LO_PLUS_PIN, INPUT);
  pinMode(AD8232_LO_MINUS_PIN, INPUT);
  pinMode(AD8232_OUT_PIN, INPUT);

  analogReadResolution(12);
  analogSetPinAttenuation(AD8232_OUT_PIN, ADC_11db);
}

bool isLeadOff() {
  if (!ECG_USE_LEAD_OFF_PINS) {
    return false;
  }
  return digitalRead(AD8232_LO_PLUS_PIN) == HIGH || digitalRead(AD8232_LO_MINUS_PIN) == HIGH;
}

int readEcgRawSample() {
  uint32_t total = 0;
  int minSample = 4095;
  int maxSample = 0;
  for (uint8_t i = 0; i < ECG_OVERSAMPLE_COUNT; ++i) {
    int sample = analogRead(AD8232_OUT_PIN);
    total += (uint32_t)sample;
    if (sample < minSample) minSample = sample;
    if (sample > maxSample) maxSample = sample;
  }

  if (ECG_OVERSAMPLE_COUNT > 2U) {
    total -= (uint32_t)minSample;
    total -= (uint32_t)maxSample;
    return (int)(total / (uint32_t)(ECG_OVERSAMPLE_COUNT - 2U));
  }

  return (int)(total / ECG_OVERSAMPLE_COUNT);
}

void initMpu() {
  pinMode(MPU_SDA_PIN, INPUT_PULLUP);
  pinMode(MPU_SCL_PIN, INPUT_PULLUP);
  delay(10);
  Wire.begin(MPU_SDA_PIN, MPU_SCL_PIN);
  Wire.setClock(100000);
  delay(20);

  const uint8_t candidateAddresses[] = {0x68, 0x69};
  for (uint8_t i = 0; i < sizeof(candidateAddresses); ++i) {
    const uint8_t address = candidateAddresses[i];
    const bool present = i2cDevicePresent(Wire, address);
    Serial.printf("[MPU6050] probe 0x%02X present=%s\n",
                  address,
                  present ? "true" : "false");
    if (!present) continue;

    if (!mpu.begin(address, &Wire)) {
      Serial.printf("[MPU6050] begin failed at 0x%02X\n", address);
      continue;
    }

    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    g_mpuReady = true;
    Serial.printf("[MPU6050] ready at 0x%02X\n", address);
    return;
  }

  logI2CBusDevices(Wire);
  Serial.println("[MPU6050] init failed");
  g_mpuReady = false;
}

void sensorTask(void*) {
  TickType_t lastWake = xTaskGetTickCount();
  uint32_t lastMpuSampleMs = 0;

  float ecgDc = 2048.0f;
  float ecgSmooth = 0.0f;
  float ecgEnvelope = 30.0f;
  float ecgDisplayBaseline = 2048.0f;
  float ecgDisplaySmooth = 0.0f;
  float ecgDisplayEnvelope = 18.0f;
  float ecgDisplayWindow[5] = {0.0f};
  float ecgDisplayWindowSum = 0.0f;
  size_t ecgDisplayWindowHead = 0;
  bool ecgPeakArmed = false;
  bool stableLeadOff = true;
  bool leadOffCandidate = true;
  uint32_t leadStateChangedMs = 0;
  bool leadSignalQualified = false;
  bool leadOperationalOff = true;
  uint32_t leadConnectCandidateMs = 0;
  uint32_t signalInvalidSinceMs = 0;
  uint32_t lastRPeakMs = 0;
  uint32_t lastStableHrMs = 0;
  uint32_t rrHistory[ECG_RR_HISTORY_SIZE] = {0};
  size_t rrHistoryCount = 0;
  size_t rrHistoryIndex = 0;
  int lastStableHr = 0;
  float prevPeakSignal = 0.0f;
  float prevPrevPeakSignal = 0.0f;

  float motionLocal = 0.0f;
  bool lastFallState = false;

  while (true) {
    uint32_t nowMs = millis();

    // ===== ECG =====
    bool rawLeadOff = isLeadOff();
    if (rawLeadOff != leadOffCandidate) {
      leadOffCandidate = rawLeadOff;
      leadStateChangedMs = nowMs;
    }

    bool leadStateChanged = false;
    if (leadOffCandidate != stableLeadOff &&
        (nowMs - leadStateChangedMs) >= ECG_LEAD_DEBOUNCE_MS) {
      stableLeadOff = leadOffCandidate;
      leadStateChanged = true;
    }

    int raw = readEcgRawSample();

    if (leadStateChanged) {
      if (!stableLeadOff) {
        leadConnectCandidateMs = nowMs;
        signalInvalidSinceMs = 0;
        leadSignalQualified = false;
        ecgDc = (float)raw;
        ecgSmooth = 0.0f;
        ecgEnvelope = 0.0f;
        ecgDisplayBaseline = (float)raw;
        ecgDisplaySmooth = 0.0f;
        ecgDisplayEnvelope = 18.0f;
        ecgDisplayWindowSum = 0.0f;
        ecgDisplayWindowHead = 0U;
        for (size_t i = 0; i < 5U; ++i) ecgDisplayWindow[i] = 0.0f;
        prevPeakSignal = 0.0f;
        prevPrevPeakSignal = 0.0f;
      } else {
        leadConnectCandidateMs = 0;
        signalInvalidSinceMs = 0;
        leadSignalQualified = false;
      }
    }

    int hrFromEcg = 0;
    int qualityPct = 0;
    float waveformSample = 0.0f;
    bool rawInRange = raw >= ECG_ADC_VALID_MIN && raw <= ECG_ADC_VALID_MAX;

    if (!stableLeadOff) {
      float hp = (float)raw - ecgDc;
      ecgDc += ECG_DC_ALPHA * ((float)raw - ecgDc);
      ecgSmooth += ECG_BAND_ALPHA * (hp - ecgSmooth);
      float previewSignal = fabsf(ecgSmooth);
      ecgEnvelope += ECG_ENVELOPE_ALPHA * (previewSignal - ecgEnvelope);

      ecgDisplayBaseline += ECG_DISPLAY_BASELINE_ALPHA * ((float)raw - ecgDisplayBaseline);
      float ecgDisplayHp = (float)raw - ecgDisplayBaseline;
      ecgDisplayWindowSum -= ecgDisplayWindow[ecgDisplayWindowHead];
      ecgDisplayWindow[ecgDisplayWindowHead] = ecgDisplayHp;
      ecgDisplayWindowSum += ecgDisplayWindow[ecgDisplayWindowHead];
      ecgDisplayWindowHead = (ecgDisplayWindowHead + 1U) % 5U;
      float ecgDisplayNotch = ecgDisplayWindowSum / 5.0f;
      ecgDisplaySmooth += ECG_DISPLAY_SMOOTH_ALPHA * (ecgDisplayNotch - ecgDisplaySmooth);
      ecgDisplayEnvelope += ECG_DISPLAY_ENVELOPE_ALPHA * (fabsf(ecgDisplaySmooth) - ecgDisplayEnvelope);

      const float envelopeMin = leadSignalQualified ? ECG_CONTACT_ENVELOPE_HOLD_MIN
                                                    : ECG_CONTACT_ENVELOPE_MIN;
      const float envelopeMax = leadSignalQualified ? ECG_CONTACT_ENVELOPE_HOLD_MAX
                                                    : ECG_CONTACT_ENVELOPE_MAX;
      bool signalPlausible =
        rawInRange &&
        ecgEnvelope >= envelopeMin &&
        ecgEnvelope <= envelopeMax;

      if (!leadSignalQualified) {
        if (signalPlausible) {
          if (leadConnectCandidateMs == 0) leadConnectCandidateMs = nowMs;
          if ((nowMs - leadConnectCandidateMs) >= ECG_CONNECT_STABLE_MS) {
            leadSignalQualified = true;
            signalInvalidSinceMs = 0;
          }
        } else {
          leadConnectCandidateMs = nowMs;
        }
      } else {
        if (!signalPlausible) {
          if (signalInvalidSinceMs == 0) signalInvalidSinceMs = nowMs;
          uint32_t invalidTimeout = ECG_SIGNAL_INVALID_MS;
          if (lastStableHr > 0 && (nowMs - lastStableHrMs) <= ECG_HR_HOLD_MS) {
            invalidTimeout = ECG_SIGNAL_INVALID_HR_GRACE_MS;
          }
          if ((nowMs - signalInvalidSinceMs) >= invalidTimeout) {
            leadSignalQualified = false;
            leadConnectCandidateMs = nowMs;
          }
        } else {
          signalInvalidSinceMs = 0;
        }
      }
    } else {
      ecgPeakArmed = false;
      ecgDc = (float)raw;
      ecgSmooth = 0.0f;
      ecgEnvelope = 0.0f;
      ecgDisplayBaseline = (float)raw;
      ecgDisplaySmooth = 0.0f;
      ecgDisplayEnvelope = 18.0f;
      ecgDisplayWindowSum = 0.0f;
      ecgDisplayWindowHead = 0U;
      for (size_t i = 0; i < 5U; ++i) ecgDisplayWindow[i] = 0.0f;
      prevPeakSignal = 0.0f;
      prevPrevPeakSignal = 0.0f;
    }

    bool leadOff = stableLeadOff || !leadSignalQualified;
    if (leadOff != leadOperationalOff) {
      leadOperationalOff = leadOff;
      ecgPeakArmed = false;
      lastRPeakMs = 0;
      lastStableHrMs = 0;
      rrHistoryCount = 0;
      rrHistoryIndex = 0;
      lastStableHr = 0;
      prevPeakSignal = 0.0f;
      prevPrevPeakSignal = 0.0f;
      for (size_t i = 0; i < ECG_RR_HISTORY_SIZE; ++i) {
        rrHistory[i] = 0;
      }
      if (!leadOff) {
        ecgDc = (float)raw;
        ecgSmooth = 0.0f;
        ecgDisplayBaseline = (float)raw;
        ecgDisplaySmooth = 0.0f;
        ecgDisplayEnvelope = 18.0f;
        ecgDisplayWindowSum = 0.0f;
        ecgDisplayWindowHead = 0U;
        for (size_t i = 0; i < 5U; ++i) ecgDisplayWindow[i] = 0.0f;
      }
    }

    if (!leadOff) {
      float peakSignal = fabsf(ecgSmooth);
      float dynamicThreshold = ecgEnvelope * ECG_THRESHOLD_SCALE;
      if (dynamicThreshold < ECG_THRESHOLD_MIN) dynamicThreshold = ECG_THRESHOLD_MIN;
      dynamicThreshold *= 1.0f + (fminf(fabsf(motionLocal), 1.5f) * ECG_MOTION_THRESHOLD_BOOST);

      if (ENABLE_ECG_HEART_RATE) {
        bool localPeak = prevPeakSignal >= prevPrevPeakSignal && prevPeakSignal > peakSignal;
        bool above = prevPeakSignal > dynamicThreshold;
        if (above &&
            localPeak &&
            !ecgPeakArmed &&
            (lastRPeakMs == 0 || (nowMs - lastRPeakMs) >= ECG_REFACTORY_MS)) {
          ecgPeakArmed = true;
          if (lastRPeakMs != 0) {
            uint32_t rr = nowMs - lastRPeakMs;
            if (rr >= ECG_RR_MIN_MS && rr <= ECG_RR_MAX_MS) {
              rrHistory[rrHistoryIndex] = rr;
              rrHistoryIndex = (rrHistoryIndex + 1U) % ECG_RR_HISTORY_SIZE;
              if (rrHistoryCount < ECG_RR_HISTORY_SIZE) rrHistoryCount++;

              uint32_t medianRr = 0;
              if (rrWindowStable(rrHistory, rrHistoryCount, medianRr) && medianRr > 0) {
                int hrCandidate = (int)(60000UL / medianRr);
                if (hrCandidate >= 35 && hrCandidate <= 210) {
                  if (lastStableHr > 0 &&
                      abs(hrCandidate - lastStableHr) > ECG_MAX_HR_STEP_BPM &&
                      (nowMs - lastStableHrMs) <= ECG_HR_HOLD_MS) {
                    hrCandidate = (lastStableHr * 3 + hrCandidate) / 4;
                  }

                  if (lastStableHr > 0) {
                    hrCandidate = (int)roundf(((float)lastStableHr * (1.0f - ECG_HR_SMOOTHING_ALPHA)) +
                                              ((float)hrCandidate * ECG_HR_SMOOTHING_ALPHA));
                  }

                  lastStableHr = hrCandidate;
                  lastStableHrMs = nowMs;
                }
              }
            }
          }
          lastRPeakMs = nowMs;
        }
        if (peakSignal < dynamicThreshold * ECG_RELEASE_RATIO) {
          ecgPeakArmed = false;
        }

        if (lastStableHr > 0 && (nowMs - lastStableHrMs) <= ECG_HR_HOLD_MS) {
          hrFromEcg = lastStableHr;
        } else {
          hrFromEcg = 0;
          if ((nowMs - lastStableHrMs) > ECG_HR_HOLD_MS) {
            lastStableHr = 0;
          }
        }
      } else {
        ecgPeakArmed = false;
        hrFromEcg = 0;
        lastRPeakMs = 0;
        lastStableHr = 0;
        lastStableHrMs = 0;
        rrHistoryCount = 0;
        rrHistoryIndex = 0;
      }

      prevPrevPeakSignal = prevPeakSignal;
      prevPeakSignal = peakSignal;

      qualityPct = constrain((int)((ecgEnvelope - 8.0f) * 2.4f), 0, 100);
      qualityPct -= constrain((int)(fminf(fabsf(motionLocal), 1.5f) * 12.0f), 0, 30);
      if (qualityPct < 0) qualityPct = 0;

      float displayGain = fmaxf(ecgDisplayEnvelope * ECG_DISPLAY_GAIN_SCALE, ECG_DISPLAY_GAIN_MIN);
      waveformSample = ecgDisplaySmooth / displayGain;
      if (waveformSample > 1.0f) waveformSample = 1.0f;
      if (waveformSample < -1.0f) waveformSample = -1.0f;
    }

    portENTER_CRITICAL(&g_sensorMux);
    g_latestEcgRaw = raw;
    g_latestLeadOff = leadOff;
    g_ecgDerivedHeartRate = hrFromEcg;
    g_ecgQualityPct = qualityPct;
    g_ecgWaveform[g_ecgWaveformHead] = waveformSample;
    g_ecgWaveformHead = (g_ecgWaveformHead + 1U) % ECG_WAVEFORM_SAMPLES;
    if (g_ecgWaveformHead == 0U) {
      g_ecgWaveformFilled = true;
    }
    portEXIT_CRITICAL(&g_sensorMux);

    // ===== FALL from MPU =====
    if (g_mpuReady && (nowMs - lastMpuSampleMs) >= MPU_SAMPLE_INTERVAL_MS) {
      lastMpuSampleMs = nowMs;

      sensors_event_t a, g, tempEvt;
      mpu.getEvent(&a, &g, &tempEvt);

      FallPhase fallPhase = FALL_PHASE_IDLE;
      float accelMagG = 1.0f;
      float gyroMagDps = 0.0f;
      float tiltDeg = 0.0f;
      float impactMagG = 0.0f;
      bool fallDetected = updateFallDetection(a,
                                              g,
                                              nowMs,
                                              motionLocal,
                                              fallPhase,
                                              accelMagG,
                                              gyroMagDps,
                                              tiltDeg,
                                              impactMagG);

      portENTER_CRITICAL(&g_sensorMux);
      g_fallDetected = fallDetected;
      g_fallPhase = fallPhase;
      portEXIT_CRITICAL(&g_sensorMux);

      if (fallDetected && !lastFallState) {
        latchFallAlert(fallPhase, nowMs);
        Serial.printf("[FALL] detected A=%.2fg G=%.0fdps tilt=%.1fdeg impact=%.2fg phase=%s\n",
                      accelMagG,
                      gyroMagDps,
                      tiltDeg,
                      impactMagG,
                      fallPhaseText(fallPhase));
      }
      lastFallState = fallDetected;
    }

    vTaskDelayUntil(&lastWake, pdMS_TO_TICKS(SENSOR_TASK_PERIOD_MS));
  }
}

// ===================== BLE RX =====================
bool parseC3Json(const std::string& raw, C3Packet& out) {
  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, raw.c_str());
  if (err) return false;

  out.hr = doc["hr"] | 0;
  out.spo2 = doc["spo2"] | 0;
  out.temp = doc["temp"].isNull() ? NAN : doc["temp"].as<float>();
  out.q = doc["q"] | 0;
  out.sim = doc["sim"] | false;
  out.lastUpdateMs = millis();
  out.valid = true;
  return true;
}

class BleServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer*, NimBLEConnInfo& connInfo) override {
    g_bleClientConnected = true;
    g_bleSawConnection = true;
    g_bleConnectCount++;
    g_bleConnHandle = connInfo.getConnHandle();
    g_bleAdvertisingOn = false;

    Serial.printf("[BLE] client connected (count=%lu, handle=%u)\n",
                  (unsigned long)g_bleConnectCount,
                  (unsigned)g_bleConnHandle);
  }

  void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int reason) override {
    g_bleClientConnected = false;
    g_bleConnHandle = 0xFFFF;
    Serial.printf("[BLE] client disconnected, reason=%d\n", reason);

    if (g_bleWindowOpen && g_bleAdvertising != nullptr) {
      g_bleAdvertising->start();
      g_bleAdvertisingOn = true;
      Serial.println("[BLE] advertising resumed");
    }
  }
};

class BleWriteCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pCharacteristic, NimBLEConnInfo&) override {
    std::string raw = pCharacteristic->getValue();
    Serial.printf("[BLE] RX raw: %s\n", raw.c_str());

    C3Packet parsed;
    if (!parseC3Json(raw, parsed)) {
      Serial.println("[BLE] parse FAILED");
      return;
    }

    portENTER_CRITICAL(&g_c3Mux);
    g_latestC3 = parsed;
    portEXIT_CRITICAL(&g_c3Mux);

    g_c3PacketReceivedThisCycle = true;
    g_lastC3PacketRxMs = parsed.lastUpdateMs;

    Serial.printf("[BLE] parsed OK HR=%d SpO2=%d Temp=%.1f q=%d sim=%s\n",
                  parsed.hr,
                  parsed.spo2,
                  parsed.temp,
                  parsed.q,
                  parsed.sim ? "true" : "false");
  }
};

static BleServerCallbacks g_bleCallbacks;
static BleWriteCallbacks g_bleWriteCallbacks;

void initBleStackOnce() {
  if (g_bleInitialized) return;

  Serial.println("[BLE] init stack...");
  NimBLEDevice::init(BLE_DEVICE_NAME);
  NimBLEDevice::setPower(9);
  NimBLEDevice::setMTU(247);

  g_bleServer = NimBLEDevice::createServer();
  g_bleServer->setCallbacks(&g_bleCallbacks);
  g_bleServer->advertiseOnDisconnect(true);

  NimBLEService* service = g_bleServer->createService(BLE_SERVICE_UUID);

  g_bleWriteChar = service->createCharacteristic(
    BLE_WRITE_UUID,
    NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
  );
  g_bleWriteChar->setCallbacks(&g_bleWriteCallbacks);

  service->start();

  g_bleAdvertising = NimBLEDevice::getAdvertising();
  g_bleAdvertising->addServiceUUID(BLE_SERVICE_UUID);
  g_bleAdvertising->enableScanResponse(true);
  g_bleAdvertising->setName(BLE_DEVICE_NAME);

  g_bleInitialized = true;
  Serial.println("[BLE] stack ready");
}

void startBleWindow() {
  if (!g_bleInitialized) {
    initBleStackOnce();
  }

  g_bleClientConnected = false;
  g_bleSawConnection = false;
  g_bleConnectCount = 0;
  g_c3PacketReceivedThisCycle = false;
  g_lastC3PacketRxMs = 0;
  g_lastBleStatusLogMs = millis();
  g_bleWindowOpen = true;

  if (g_bleAdvertising != nullptr && !g_bleAdvertisingOn) {
    g_bleAdvertising->stop();
    delay(30);
    if (g_bleAdvertising->start()) {
      g_bleAdvertisingOn = true;
      Serial.println("[BLE] advertising started, waiting for C3...");
    } else {
      Serial.println("[BLE] advertising start FAILED");
    }
  }
}

void stopBleWindow() {
  if (!g_bleInitialized) {
    Serial.println("[BLE] stop skipped: not initialized");
    return;
  }

  g_bleWindowOpen = false;

  if (g_bleSawConnection) {
    Serial.printf("[BLE] cycle done: had connection, total connect=%lu\n",
                  (unsigned long)g_bleConnectCount);
  } else {
    Serial.println("[BLE] cycle done: no client connected");
  }

  if (g_c3PacketReceivedThisCycle) {
    Serial.println("[BLE] cycle done: packet received from C3");
  } else {
    Serial.println("[BLE] cycle done: no packet from C3");
  }

  if (g_bleAdvertising != nullptr && g_bleAdvertisingOn) {
    g_bleAdvertising->stop();
    g_bleAdvertisingOn = false;
    Serial.println("[BLE] advertising stopped");
  }

  if (g_bleClientConnected && g_bleConnHandle != 0xFFFF) {
    Serial.printf("[BLE] disconnect client handle=%u\n", (unsigned)g_bleConnHandle);
    g_bleServer->disconnect(g_bleConnHandle);
    delay(100);
  }
}

// ===================== WIFI PORTAL =====================
String escapeHtml(String input) {
  input.replace("&", "&amp;");
  input.replace("<", "&lt;");
  input.replace(">", "&gt;");
  input.replace("\"", "&quot;");
  input.replace("'", "&#39;");
  return input;
}

String escapeJsSingleQuoted(String input) {
  input.replace("\\", "\\\\");
  input.replace("'", "\\'");
  input.replace("\r", "");
  input.replace("\n", " ");
  input.replace("<", "\\x3C");
  return input;
}

String getStoredWifiSsid() {
  wifi_config_t cfg;
  memset(&cfg, 0, sizeof(cfg));
  if (esp_wifi_get_config(WIFI_IF_STA, &cfg) != ESP_OK) {
    return String();
  }
  if (cfg.sta.ssid[0] == '\0') {
    return String();
  }
  return String(reinterpret_cast<const char*>(cfg.sta.ssid));
}

String buildPortalWifiList() {
  String out;
  int networkCount = WiFi.scanNetworks();
  if (networkCount <= 0) {
    WiFi.scanDelete();
    out += "<div style='color:#9ca3af;font-size:13px'>Khong tim thay mang Wi-Fi.</div>";
    return out;
  }

  out += "<div style='display:flex;flex-direction:column;gap:6px;max-height:240px;overflow:auto;padding:6px;border:1px solid rgba(148,163,184,.25);border-radius:12px;background:#0b1220'>";
  for (int i = 0; i < networkCount; ++i) {
    String ssid = WiFi.SSID(i);
    String htmlSsid = escapeHtml(ssid);
    String jsSsid = escapeJsSingleQuoted(ssid);

    out += "<button type='button' style='text-align:left;padding:10px;border-radius:10px;border:1px solid rgba(148,163,184,.20);background:#111a2e;color:#e5e7eb;cursor:pointer' ";
    out += "onclick=\"document.getElementById('ssid').value='";
    out += jsSsid;
    out += "'\">";
    out += "<div style='font-weight:600'>";
    out += htmlSsid;
    out += "</div>";
    out += "<div style='font-size:12px;color:#9ca3af'>RSSI ";
    out += String(WiFi.RSSI(i));
    out += " dBm</div>";
    out += "</button>";
  }
  out += "</div>";
  WiFi.scanDelete();
  return out;
}

void sendPortalLoginPage(const String& errorText = "") {
  String page = FPSTR(WIFI_LOGIN_PAGE);
  page.replace("%ERR%", escapeHtml(errorText));
  g_wm.server->send(200, "text/html", page);
}

void sendPortalWifiPage() {
  if (!g_portalLoggedIn) {
    g_wm.server->sendHeader("Location", "/", true);
    g_wm.server->send(302, "text/plain", "");
    return;
  }

  String page;
  page += "<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>";
  page += "<style>body{font-family:system-ui;background:#0b1220;color:#e5e7eb;display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}.card{width:min(440px,92vw);background:#111a2e;border:1px solid rgba(148,163,184,.35);border-radius:18px;padding:18px 16px}input{width:100%;padding:10px;border-radius:12px;border:1px solid rgba(148,163,184,.35);background:#0b1220;color:#e5e7eb;margin:8px 0}button{width:100%;padding:11px;border-radius:999px;border:none;background:#16a34a;color:white;font-weight:800;margin-top:8px}</style>";
  page += "</head><body><div class='card'>";
  page += "<h2>Wi-Fi Setup</h2>";
  page += "<div style='font-size:12px;color:#9ca3af;margin-bottom:10px'>AP: ";
  page += escapeHtml(g_wm.getConfigPortalSSID());
  page += "</div>";
  page += buildPortalWifiList();
  page += "<form method='GET' action='/wifisave'>";
  page += "<input id='ssid' name='s' placeholder='SSID' required>";
  page += "<input name='p' type='password' placeholder='Password'>";
  page += "<button type='submit'>Luu & ket noi</button></form>";
  page += "</div></body></html>";
  g_wm.server->send(200, "text/html", page);
}

void bindPortalRoutes() {
  if (g_wm.server == nullptr) return;

  g_wm.server->on("/", []() {
    if (g_portalLoggedIn) {
      g_wm.server->sendHeader("Location", "/wifi", true);
      g_wm.server->send(302, "text/plain", "");
      return;
    }
    sendPortalLoginPage();
  });

  g_wm.server->on("/login", []() {
    if (!g_wm.server->hasArg("user") || !g_wm.server->hasArg("pass")) {
      sendPortalLoginPage("Missing fields");
      return;
    }

    String user = g_wm.server->arg("user");
    String pass = g_wm.server->arg("pass");
    if (user == WIFI_PORTAL_USER && pass == WIFI_PORTAL_PASS) {
      g_portalLoggedIn = true;
      g_wm.server->sendHeader("Location", "/wifi", true);
      g_wm.server->send(302, "text/plain", "");
      return;
    }

    g_portalLoggedIn = false;
    sendPortalLoginPage("Wrong user/pass");
  });

  g_wm.server->on("/wifi", []() {
    sendPortalWifiPage();
  });
}

bool setupWiFiWithPortal(const char* apName = WIFI_PORTAL_AP_NAME,
                         const char* apPass = WIFI_PORTAL_AP_PASS,
                         uint16_t timeoutSec = WIFI_PORTAL_TIMEOUT_SEC) {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  g_portalLoggedIn = false;

  g_wm.setConfigPortalTimeout(timeoutSec);
  static std::vector<const char*> menu = {"wifi", "exit"};
  g_wm.setMenu(menu);
  g_wm.setWebServerCallback(bindPortalRoutes);

  bool connected = g_wm.autoConnect(apName, apPass);
  String storedSsid = getStoredWifiSsid();
  g_wifiCredentialsReady = storedSsid.length() > 0;

  if (connected) {
    Serial.printf("[WiFi] portal ready, connected to %s IP=%s\n",
                  WiFi.SSID().c_str(),
                  WiFi.localIP().toString().c_str());
  } else if (g_wifiCredentialsReady) {
    Serial.printf("[WiFi] portal timeout, stored SSID=%s\n", storedSsid.c_str());
  } else {
    Serial.println("[WiFi] portal timeout/failed, no stored credentials");
  }

  return connected;
}

// ===================== WIFI/HTTP =====================
bool startWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);

  String storedSsid = getStoredWifiSsid();
  g_wifiCredentialsReady = storedSsid.length() > 0;
  if (!g_wifiCredentialsReady) {
    Serial.println("[WiFi] no stored credentials, skip connect");
    return false;
  }

  Serial.printf("[WiFi] connecting to saved SSID %s\n", storedSsid.c_str());
  WiFi.begin();
  return true;
}

void stopWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("[WiFi] disconnect");
  }
  WiFi.disconnect(true, false);
  delay(50);
  WiFi.mode(WIFI_OFF);
}

void syncTimeIfNeeded() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (g_timeSynced && hasValidRtcTime()) return;

  uint32_t now = millis();
  if (now - g_lastNtpAttemptMs < NTP_RETRY_MS) return;
  g_lastNtpAttemptMs = now;

  Serial.println("[NTP] syncing...");
  configTime(7 * 3600, 0, "pool.ntp.org", "time.google.com", "time.nist.gov");

  struct timeval tv;
  for (int i = 0; i < 12; ++i) {
    delay(150);
    if (gettimeofday(&tv, nullptr) == 0 && tv.tv_sec > 1700000000) {
      g_timeSynced = true;
      Serial.println("[NTP] synced");
      return;
    }
  }

  Serial.println("[NTP] not ready yet");
}

bool httpPostJson(const String& url, const String& body, int& code, String& response) {
  HTTPClient http;
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
  http.setTimeout(HTTP_TIMEOUT_MS);

  WiFiClient plainClient;
  WiFiClientSecure secureClient;
  bool beginOk = false;

  if (url.startsWith("https://")) {
    if (USE_INSECURE_TLS) {
      secureClient.setInsecure();
    }
    beginOk = http.begin(secureClient, url);
  } else {
    beginOk = http.begin(plainClient, url);
  }

  if (!beginOk) {
    Serial.println("[HTTP] begin failed");
    code = -1;
    response = "";
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Token", DEVICE_TOKEN);

  code = http.POST(body);
  if (code > 0) {
    response = http.getString();
  } else {
    response = "";
  }

  http.end();
  return code >= 200 && code < 300;
}

// ===================== DATA MERGE =====================
Snapshot captureSnapshot() {
  Snapshot s;
  C3Packet c3;

  portENTER_CRITICAL(&g_c3Mux);
  c3 = g_latestC3;
  portEXIT_CRITICAL(&g_c3Mux);

  portENTER_CRITICAL(&g_sensorMux);
  s.hrEcg = ENABLE_ECG_HEART_RATE ? g_ecgDerivedHeartRate : 0;
  s.ecgLeadOff = g_latestLeadOff;
  s.ecgQuality = g_ecgQualityPct;
  s.fallDetected = g_fallDetected;
  s.fallPhase = (uint8_t)g_fallPhase;
  size_t start = g_ecgWaveformFilled ? g_ecgWaveformHead : 0U;
  size_t count = g_ecgWaveformFilled ? ECG_WAVEFORM_SAMPLES : g_ecgWaveformHead;
  for (size_t i = 0; i < ECG_WAVEFORM_SAMPLES; ++i) {
    if (i < count) {
      size_t idx = (start + i) % ECG_WAVEFORM_SAMPLES;
      s.ecgWaveform[i] = g_ecgWaveform[idx];
    } else {
      s.ecgWaveform[i] = 0.0f;
    }
  }
  portEXIT_CRITICAL(&g_sensorMux);

  const bool c3Available = c3.valid;
  const bool c3Fresh = c3.valid && ((millis() - c3.lastUpdateMs) <= C3_PACKET_FRESH_MS);
  const bool c3VitalsValid = c3Fresh && c3.q >= C3_MIN_VALID_QUALITY;
  s.c3Available = c3Available;
  s.c3Fresh = c3Fresh;
  s.c3Sim = c3Available ? c3.sim : false;
  s.c3Quality = c3Available ? c3.q : 0;
  s.hrBle = c3VitalsValid ? c3.hr : 0;
  s.spo2 = c3VitalsValid ? c3.spo2 : 0;
  s.temp = c3Fresh ? c3.temp : NAN;

  const bool ecgPreferred =
    ENABLE_ECG_HEART_RATE &&
    PREFER_ECG_HEART_RATE &&
    s.hrEcg > 0 &&
    !s.ecgLeadOff &&
    s.ecgQuality >= ECG_PRIMARY_HR_MIN_QUALITY;

  if (ecgPreferred) s.hr = s.hrEcg;
  else if (s.hrBle > 0) s.hr = s.hrBle;
  else s.hr = 0;

  return s;
}

String buildPayload(const Snapshot& s, bool includeC3Vitals, bool includeC3Temp) {
  bool fallPending = false;
  FallPhase fallAlertPhase = FALL_PHASE_IDLE;

  portENTER_CRITICAL(&g_sensorMux);
  fallPending = g_fallAlertPending;
  fallAlertPhase = g_fallAlertPhase;
  portEXIT_CRITICAL(&g_sensorMux);

  const bool fallValue = s.fallDetected || fallPending;
  const FallPhase payloadFallPhase = fallPending ? fallAlertPhase : (FallPhase)s.fallPhase;
  const UploadReason payloadUploadReason = fallPending ? UPLOAD_REASON_FALL_ALERT : g_uploadReason;

  String body;
  body.reserve(4096);

  body += "{";
  body += "\"timestamp\":";
  body += String(nowEpochSeconds(), 3);
  body += ",";
  body += "\"device_type\":\"";
  body += DEVICE_TYPE;
  body += "\",";
  body += "\"fall\":";
  body += (fallValue ? "true" : "false");
  body += ",";
  body += "\"fall_phase\":\"";
  body += fallPhaseText(payloadFallPhase);
  body += "\",";

  body += "\"vitals\":{";

  bool needComma = false;

  if (s.hr > 0) {
    body += "\"heart_rate\":";
    body += String(s.hr);
    needComma = true;
  }

  if (s.respiratoryRate > 0) {
    if (needComma) body += ",";
    body += "\"respiratory_rate\":";
    body += String(s.respiratoryRate);
    needComma = true;
  }

  if (includeC3Vitals && s.spo2 > 0) {
    if (needComma) body += ",";
    body += "\"spo2\":";
    body += String(s.spo2);
    needComma = true;
  }

  if (includeC3Temp && shouldUploadBodyTemperature(s.temp)) {
    if (needComma) body += ",";
    body += "\"temperature\":";
    body += String(s.temp, 1);
    needComma = true;
  }

  body += "},";

  body += "\"ecg\":{";
  body += "\"waveform\":[";
  for (size_t i = 0; i < ECG_WAVEFORM_SAMPLES; ++i) {
    if (i > 0) body += ",";
    body += String(s.ecgWaveform[i], 4);
  }
  body += "],";
  body += "\"sampling_rate\":";
  body += String(1000UL / SENSOR_TASK_PERIOD_MS);
  body += ",";
  body += "\"quality\":\"";
  body += ecgQualityText(s.ecgQuality, s.ecgLeadOff);
  body += "\",";
  body += "\"lead_off\":";
  body += (s.ecgLeadOff ? "true" : "false");
  body += ",";
  body += "\"ecg_hr\":";
  body += String(ENABLE_ECG_HEART_RATE ? s.hrEcg : 0);
  body += "},";

  body += "\"metadata\":{";
  body += "\"battery_level\":95,";
  body += "\"signal_strength\":";
  body += String(WiFi.RSSI());
  body += ",";
  body += "\"signal_quality\":";
  body += String(s.ecgQuality);
  body += ",";
  body += "\"upload_reason\":\"";
  body += uploadReasonText(payloadUploadReason);
  body += "\",";
  body += "\"firmware_version\":\"";
  body += FIRMWARE_VERSION;
  body += "\"";
  body += "}";
  body += "}";

  return body;
}

bool sendMergedReading() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[SEND] skip: WiFi not connected");
    return false;
  }

  Snapshot s = captureSnapshot();
  bool includeC3Vitals = g_c3PacketReceivedThisCycle &&
                         s.c3Fresh &&
                         s.c3Quality >= C3_MIN_VALID_QUALITY;
  bool includeTemp = g_c3PacketReceivedThisCycle &&
                     s.c3Fresh &&
                     shouldUploadBodyTemperature(s.temp);
  bool fallPending = false;

  portENTER_CRITICAL(&g_sensorMux);
  fallPending = g_fallAlertPending;
  portEXIT_CRITICAL(&g_sensorMux);

  const bool fallValue = s.fallDetected || fallPending;
  const UploadReason payloadUploadReason = fallPending ? UPLOAD_REASON_FALL_ALERT : g_uploadReason;

  String url = String(API_BASE_URL) + "/api/v1/esp/devices/" + DEVICE_ID + "/readings";
  String body = buildPayload(s, includeC3Vitals, includeTemp);

  const char* uploadMode = "S3-only";
  if (includeC3Vitals) {
    uploadMode = includeTemp ? "S3+C3" : "S3+C3-vitals";
  } else if (includeTemp) {
    uploadMode = "S3+Temp";
  }

  Serial.printf("[SEND] reason=%s mode=%s HR=%d ECG=%d BLE=%d FALL=%s SpO2=%d Temp=%.1f\n",
                uploadReasonText(payloadUploadReason),
                uploadMode,
                s.hr,
                s.hrEcg,
                s.hrBle,
                fallValue ? "true" : "false",
                includeC3Vitals ? s.spo2 : 0,
                includeTemp ? s.temp : 0.0f);

  Serial.printf("[TIME] epoch=%.3f synced=%s validRtc=%s\n",
                nowEpochSeconds(),
                g_timeSynced ? "true" : "false",
                hasValidRtcTime() ? "true" : "false");

  int code = -1;
  String response;
  bool ok = false;
  for (uint8_t attempt = 1; attempt <= HTTP_RETRY_COUNT; ++attempt) {
    code = -1;
    response = "";
    ok = httpPostJson(url, body, code, response);

    Serial.printf("[HTTP] attempt %u/%u POST %s -> %d\n",
                  attempt,
                  HTTP_RETRY_COUNT,
                  url.c_str(),
                  code);
    Serial.println("[HTTP] payload:");
    Serial.println(body);

    if (response.length() > 0) {
      Serial.println("[HTTP] response:");
      Serial.println(response);
    }

    if (ok || attempt >= HTTP_RETRY_COUNT) {
      break;
    }

    Serial.println("[HTTP] upload failed, retrying...");
    delay(HTTP_RETRY_BACKOFF_MS);
  }

  Serial.println(ok ? "[HTTP] upload success" : "[HTTP] upload failed");
  if (ok && fallPending) {
    clearFallAlert();
  }
  return ok;
}

void logHealthSummary(const Snapshot& s) {
  Serial.printf(
    "[HEALTH] heap=%lu wifi=%s ble=%s hr=%d fall=%s phase=%s pending=%s upload=%s ecgLead=%s ecgQ=%d spo2=%d temp=%.1f c3Fresh=%s packetThisCycle=%s\n",
    (unsigned long)ESP.getFreeHeap(),
    WiFi.status() == WL_CONNECTED ? "OK" : "OFF",
    g_bleClientConnected ? "CONN" : "WAIT",
    s.hr,
    s.fallDetected ? "true" : "false",
    fallPhaseText((FallPhase)s.fallPhase),
    g_fallAlertPending ? "true" : "false",
    uploadReasonText(g_uploadReason),
    s.ecgLeadOff ? "OFF" : "ON",
    s.ecgQuality,
    s.spo2,
    isnan(s.temp) ? 0.0f : s.temp,
    s.c3Fresh ? "true" : "false",
    g_c3PacketReceivedThisCycle ? "true" : "false"
  );
}

// ===================== SETUP / LOOP =====================
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("ESP32-S3 gateway start (NimBLE, no-seq)");
  printResetReason();

  initAd8232();
  initMpu();
  initDisplay();

  xTaskCreate(sensorTask, "sensorTask", 6144, nullptr, 1, &g_sensorTaskHandle);

  setupWiFiWithPortal();
  stopWiFi();

  initBleStackOnce();
  startBleWindow();

  changeState(STATE_BLE_ACTIVE);
}

void loop() {
  uint32_t now = millis();

  if ((now - g_lastDisplayRefreshMs) >= 1000UL) {
    g_lastDisplayRefreshMs = now;
    refreshDisplay();
  }

  switch (g_state) {
    case STATE_BLE_ACTIVE:
      if ((now - g_lastBleStatusLogMs) >= 5000UL) {
        g_lastBleStatusLogMs = now;
        if (g_bleClientConnected) {
          Serial.println("[BLE] status: client is connected");
        } else {
          Serial.println("[BLE] status: waiting for client...");
        }
      }

      if ((now - g_lastHealthLogMs) >= 5000UL) {
        g_lastHealthLogMs = now;
        logHealthSummary(captureSnapshot());
      }

      if (g_fallAlertPending) {
        g_uploadReason = UPLOAD_REASON_FALL_ALERT;
        Serial.println("[FLOW] fall alert pending -> stop BLE and upload");
        changeState(STATE_BLE_STOP);
      } else if (g_c3PacketReceivedThisCycle &&
          (int32_t)(now - g_lastC3PacketRxMs) >= (int32_t)BLE_POST_RX_GUARD_MS) {
        g_uploadReason = UPLOAD_REASON_ROUTINE;
        Serial.println("[FLOW] C3 packet received -> stop BLE and upload");
        changeState(STATE_BLE_STOP);
      }
      break;

    case STATE_BLE_STOP:
      stopBleWindow();
      g_guardUntilMs = millis() + BLE_TO_WIFI_GUARD_MS;
      changeState(STATE_WIFI_START);
      break;

    case STATE_WIFI_START:
      if ((int32_t)(millis() - g_guardUntilMs) < 0) {
        break;
      }
      if (startWiFi()) {
        changeState(STATE_WIFI_WAIT);
      } else {
        changeState(STATE_CLEANUP);
      }
      break;

    case STATE_WIFI_WAIT:
      if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("[WiFi] connected, IP=%s RSSI=%d\n",
                      WiFi.localIP().toString().c_str(),
                      WiFi.RSSI());
        syncTimeIfNeeded();
        changeState(STATE_SEND);
      } else if ((now - g_stateStartedMs) >= WIFI_CONNECT_TIMEOUT_MS) {
        Serial.println("[WiFi] connect timeout");
        changeState(STATE_CLEANUP);
      }
      break;

    case STATE_SEND:
      sendMergedReading();
      g_uploadReason = UPLOAD_REASON_NONE;
      changeState(STATE_CLEANUP);
      break;

    case STATE_CLEANUP:
      stopWiFi();
      g_uploadReason = UPLOAD_REASON_NONE;
      startBleWindow();
      changeState(STATE_BLE_ACTIVE);
      break;

    default:
      changeState(STATE_CLEANUP);
      break;
  }

  delay(20);
}
