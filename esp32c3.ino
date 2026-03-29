#include <Arduino.h>
#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <MAX3010x.h>
#include <NimBLEDevice.h>
#include <NimBLEUtils.h>
#include <ArduinoJson.h>
#include <esp_system.h>

// =====================================================
// ESP32-C3 WRIST CLIENT - NimBLE version, no seq
// - Den ky gui thi scan S3 cho den khi tim thay
// - Connect vao S3
// - Ghi JSON khong co seq sang S3
// - Disconnect ngay sau khi gui
// - Cho chu ky tiep theo roi lap lai
// =====================================================

// ===================== CONFIG =====================
static const char* GATEWAY_NAME     = "Eldercare-ESP32";
static const char* SERVICE_UUID     = "12345678-1234-1234-1234-1234567890ab";
static const char* WRITE_CHAR_UUID  = "12345678-1234-1234-1234-1234567890ad";

static const uint32_t SCAN_WINDOW_MS   = 3000UL;
static const uint32_t SEND_INTERVAL_MS = 30000UL;
static const uint32_t BLE_CONNECT_TIMEOUT_MS = 5000UL;
static const uint32_t SEND_RETRY_BACKOFF_MS = 1500UL;
static const uint32_t CONNECT_FAIL_BACKOFF_MS = 400UL;
static const uint32_t POST_DISCONNECT_DELAY_MS = 200UL;
static const uint32_t PRE_CONNECT_SETTLE_MS = 80UL;
static const uint8_t CONNECT_RETRY_COUNT = 3;
static const int MAX30102_SCL_PIN = 4;
static const int MAX30102_SDA_PIN = 3;
static const int DS18B20_DQ_PIN   = 8;
static const uint32_t TEMP_READ_INTERVAL_MS = 1000UL;
static const uint32_t TEMP_CONVERSION_MS    = 750UL;
static const uint32_t TEMP_RESCAN_INTERVAL_MS = 5000UL;
static const uint32_t VITALS_LOG_INTERVAL_MS = 5000UL;

// true = test ngay bang fake data
// false = thay readRealVitals() bang code sensor that cua ban
static const bool USE_FAKE_SENSOR_DATA = false;

static const float MAX30102_SAMPLING_FREQUENCY = 100.0f;
// Tuned for easier SpO2 lock with a finger resting on the sensor.
static const uint32_t MAX30102_FINGER_THRESHOLD = 4000UL;
static const uint32_t MAX30102_FINGER_COOLDOWN_MS = 350UL;
static const float MAX30102_EDGE_THRESHOLD = -180.0f;
static const float MAX30102_LOW_PASS_CUTOFF = 5.0f;
static const float MAX30102_HIGH_PASS_CUTOFF = 0.5f;
static const uint8_t MAX30102_AVERAGING_SAMPLES = 6U;
static const uint8_t MAX30102_MIN_AVG_SAMPLES = 1U;
static const uint8_t MAX30102_STABILITY_WINDOW = 5U;
static const uint8_t MAX30102_MIN_STABLE_BEATS = 3U;
static const uint32_t MAX30102_HR_HOLD_MS = 8000UL;
static const uint32_t MAX30102_VALUE_HOLD_MS = 12000UL;
static const uint32_t MAX30102_MEASUREMENT_TIMEOUT_MS = 25000UL;
static const uint32_t MAX30102_REINIT_INTERVAL_MS = 5000UL;
static const int MAX30102_HR_MIN_BPM = 42;
static const int MAX30102_HR_MAX_BPM = 210;
static const int MAX30102_MIN_REPORT_QUALITY = 20;
static const int MAX30102_MAX_BPM_MEAN_ABS_DEV = 10;
static const int MAX30102_MAX_BPM_SPAN = 18;
static const float MAX30102_MAX_SPO2_MEAN_ABS_DEV = 2.5f;
static const float MAX30102_MAX_SPO2_SPAN = 5.0f;
static const float MAX30102_RED_RANGE_MIN = 12.0f;
static const float MAX30102_IR_RANGE_MIN = 12.0f;
static const float MAX30102_RED_AVG_MIN = 700.0f;
static const float MAX30102_IR_AVG_MIN = 700.0f;
static const float MAX30102_SPO2_MIN = 72.0f;
static const float MAX30102_SPO2_MAX = 100.0f;
static const float MAX30102_SPO2_A = 1.5958422f;
static const float MAX30102_SPO2_B = -34.6596622f;
static const float MAX30102_SPO2_C = 112.6898759f;
static const uint8_t MAX30102_RED_LED_CURRENT = 110U;
static const uint8_t MAX30102_IR_LED_CURRENT = 110U;

// ===================== TYPES =====================
struct WristVitals {
  int hr = 0;
  int spo2 = 0;
  float temp = NAN;
  int q = 0;
  bool sim = false;
};

class MinMaxAvgStatistic {
  float min_ = NAN;
  float max_ = NAN;
  float sum_ = 0.0f;
  int count_ = 0;
public:
  void process(float value) {
    min_ = isnan(min_) ? value : min(min_, value);
    max_ = isnan(max_) ? value : max(max_, value);
    sum_ += value;
    count_++;
  }

  void reset() {
    min_ = NAN;
    max_ = NAN;
    sum_ = 0.0f;
    count_ = 0;
  }

  float minimum() const { return min_; }
  float maximum() const { return max_; }
  float average() const { return count_ > 0 ? (sum_ / (float)count_) : NAN; }
  int count() const { return count_; }
};

class HighPassFilter {
  const float kX;
  const float kA0;
  const float kA1;
  const float kB1;
  float lastFilterValue_ = NAN;
  float lastRawValue_ = NAN;
public:
  HighPassFilter(float cutoff, float samplingFrequency)
    : kX(expf(-1.0f / (samplingFrequency / (cutoff * 2.0f * PI)))),
      kA0((1.0f + kX) * 0.5f),
      kA1(-kA0),
      kB1(kX) {}

  float process(float value) {
    if (isnan(lastFilterValue_) || isnan(lastRawValue_)) {
      lastFilterValue_ = 0.0f;
    } else {
      lastFilterValue_ = (kA0 * value) + (kA1 * lastRawValue_) + (kB1 * lastFilterValue_);
    }
    lastRawValue_ = value;
    return lastFilterValue_;
  }

  void reset() {
    lastFilterValue_ = NAN;
    lastRawValue_ = NAN;
  }
};

class LowPassFilter {
  const float kX;
  const float kA0;
  const float kB1;
  float lastValue_ = NAN;
public:
  LowPassFilter(float cutoff, float samplingFrequency)
    : kX(expf(-1.0f / (samplingFrequency / (cutoff * 2.0f * PI)))),
      kA0(1.0f - kX),
      kB1(kX) {}

  float process(float value) {
    if (isnan(lastValue_)) {
      lastValue_ = value;
    } else {
      lastValue_ = (kA0 * value) + (kB1 * lastValue_);
    }
    return lastValue_;
  }

  void reset() {
    lastValue_ = NAN;
  }
};

class Differentiator {
  const float samplingFrequency_;
  float lastValue_ = NAN;
public:
  explicit Differentiator(float samplingFrequency)
    : samplingFrequency_(samplingFrequency) {}

  float process(float value) {
    float diff = (value - lastValue_) * samplingFrequency_;
    lastValue_ = value;
    return diff;
  }

  void reset() {
    lastValue_ = NAN;
  }
};

template<size_t BufferSize> class MovingAverageFilter {
  size_t index_ = 0;
  size_t count_ = 0;
  float values_[BufferSize] = {0.0f};
public:
  float process(float value) {
    values_[index_] = value;
    index_ = (index_ + 1U) % BufferSize;
    if (count_ < BufferSize) count_++;

    float sum = 0.0f;
    for (size_t i = 0; i < count_; ++i) {
      sum += values_[i];
    }
    return count_ > 0 ? (sum / (float)count_) : value;
  }

  void reset() {
    index_ = 0;
    count_ = 0;
  }

  size_t count() const {
    return count_;
  }
};

// ===================== GLOBALS =====================
static MAX30102 pulseOxSensor;
static OneWire oneWireBus(DS18B20_DQ_PIN);
static DallasTemperature tempSensor(&oneWireBus);
static NimBLEClient* bleClient = nullptr;
static NimBLERemoteCharacteristic* remoteWriteChar = nullptr;
static NimBLEAddress selectedGatewayAddr;
static bool selectedGatewayAddrValid = false;
static NimBLEAddress cachedGatewayAddr;
static bool cachedGatewayAddrValid = false;
static uint32_t lastSendMs = 0;
static uint32_t lastSendAttemptMs = 0;
static bool sendPending = false;
static bool measurementActive = false;
static uint32_t measurementStartedMs = 0;
static uint32_t lastAliveMs = 0;
static uint32_t lastVitalsLogMs = 0;

static bool pulseOxReady = false;
static bool ds18b20Ready = false;
static bool ds18b20ConversionPending = false;
static uint32_t lastTempRequestMs = 0;
static uint32_t lastTempRescanMs = 0;
static WristVitals latestVitals;

static LowPassFilter pulseOxLowPassRed(MAX30102_LOW_PASS_CUTOFF, MAX30102_SAMPLING_FREQUENCY);
static LowPassFilter pulseOxLowPassIr(MAX30102_LOW_PASS_CUTOFF, MAX30102_SAMPLING_FREQUENCY);
static HighPassFilter pulseOxHighPass(MAX30102_HIGH_PASS_CUTOFF, MAX30102_SAMPLING_FREQUENCY);
static Differentiator pulseOxDifferentiator(MAX30102_SAMPLING_FREQUENCY);
static MovingAverageFilter<MAX30102_AVERAGING_SAMPLES> pulseOxHrAverage;
static MovingAverageFilter<MAX30102_AVERAGING_SAMPLES> pulseOxSpo2Average;
static MinMaxAvgStatistic pulseOxRedStat;
static MinMaxAvgStatistic pulseOxIrStat;
static uint32_t lastHeartbeatMs = 0;
static uint32_t lastCrossedMs = 0;
static uint32_t fingerTimestampMs = 0;
static uint32_t lastValidPulseOxMs = 0;
static uint32_t lastPulseOxInitAttemptMs = 0;
static float lastDiff = NAN;
static bool fingerDetected = false;
static bool crossed = false;
static int pulseOxBpmHistory[MAX30102_STABILITY_WINDOW] = {0};
static float pulseOxSpo2History[MAX30102_STABILITY_WINDOW] = {0.0f};
static size_t pulseOxBeatHistoryCount = 0;
static size_t pulseOxBeatHistoryIndex = 0;

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

WristVitals generateFakeVitals() {
  uint32_t t = millis() / 1000UL;

  WristVitals v;
  v.hr = 72 + (int)(t % 11UL) - 5;
  v.spo2 = 97 + (int)(t % 3UL);
  v.temp = 36.4f + (0.1f * (float)(t % 5UL));
  v.q = 92 - (int)(t % 8UL);
  v.sim = true;
  return v;
}

int clampQuality(int value) {
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

int medianIntWindow(const int* values, size_t count) {
  if (count == 0) return 0;

  int scratch[MAX30102_STABILITY_WINDOW] = {0};
  for (size_t i = 0; i < count; ++i) {
    scratch[i] = values[i];
  }

  for (size_t i = 1; i < count; ++i) {
    int value = scratch[i];
    size_t j = i;
    while (j > 0 && scratch[j - 1] > value) {
      scratch[j] = scratch[j - 1];
      --j;
    }
    scratch[j] = value;
  }

  if ((count % 2U) == 1U) return scratch[count / 2U];
  return (scratch[(count / 2U) - 1U] + scratch[count / 2U]) / 2;
}

float medianFloatWindow(const float* values, size_t count) {
  if (count == 0) return NAN;

  float scratch[MAX30102_STABILITY_WINDOW] = {0.0f};
  for (size_t i = 0; i < count; ++i) {
    scratch[i] = values[i];
  }

  for (size_t i = 1; i < count; ++i) {
    float value = scratch[i];
    size_t j = i;
    while (j > 0 && scratch[j - 1] > value) {
      scratch[j] = scratch[j - 1];
      --j;
    }
    scratch[j] = value;
  }

  if ((count % 2U) == 1U) return scratch[count / 2U];
  return (scratch[(count / 2U) - 1U] + scratch[count / 2U]) * 0.5f;
}

int spanIntWindow(const int* values, size_t count) {
  if (count == 0) return 0;

  int minValue = values[0];
  int maxValue = values[0];
  for (size_t i = 1; i < count; ++i) {
    if (values[i] < minValue) minValue = values[i];
    if (values[i] > maxValue) maxValue = values[i];
  }
  return maxValue - minValue;
}

float spanFloatWindow(const float* values, size_t count) {
  if (count == 0) return 0.0f;

  float minValue = values[0];
  float maxValue = values[0];
  for (size_t i = 1; i < count; ++i) {
    if (values[i] < minValue) minValue = values[i];
    if (values[i] > maxValue) maxValue = values[i];
  }
  return maxValue - minValue;
}

float meanAbsDeviationIntWindow(const int* values, size_t count, int center) {
  if (count == 0) return 0.0f;

  float total = 0.0f;
  for (size_t i = 0; i < count; ++i) {
    total += fabsf((float)values[i] - (float)center);
  }
  return total / (float)count;
}

float meanAbsDeviationFloatWindow(const float* values, size_t count, float center) {
  if (count == 0) return 0.0f;

  float total = 0.0f;
  for (size_t i = 0; i < count; ++i) {
    total += fabsf(values[i] - center);
  }
  return total / (float)count;
}

bool pulseOxWindowStable(int& bpmMedianOut, float& spo2MedianOut) {
  if (pulseOxBeatHistoryCount < MAX30102_MIN_STABLE_BEATS) {
    return false;
  }

  bpmMedianOut = medianIntWindow(pulseOxBpmHistory, pulseOxBeatHistoryCount);
  spo2MedianOut = medianFloatWindow(pulseOxSpo2History, pulseOxBeatHistoryCount);

  const float bpmMeanAbsDev = meanAbsDeviationIntWindow(pulseOxBpmHistory,
                                                        pulseOxBeatHistoryCount,
                                                        bpmMedianOut);
  const float spo2MeanAbsDev = meanAbsDeviationFloatWindow(pulseOxSpo2History,
                                                           pulseOxBeatHistoryCount,
                                                           spo2MedianOut);
  const int bpmSpan = spanIntWindow(pulseOxBpmHistory, pulseOxBeatHistoryCount);
  const float spo2Span = spanFloatWindow(pulseOxSpo2History, pulseOxBeatHistoryCount);

  return bpmMeanAbsDev <= (float)MAX30102_MAX_BPM_MEAN_ABS_DEV &&
         bpmSpan <= MAX30102_MAX_BPM_SPAN &&
         spo2MeanAbsDev <= MAX30102_MAX_SPO2_MEAN_ABS_DEV &&
         spo2Span <= MAX30102_MAX_SPO2_SPAN;
}

void clearPulseOxVitals() {
  latestVitals.hr = 0;
  latestVitals.spo2 = 0;
  latestVitals.q = 0;
}

void resetPulseOxAlgorithm(bool clearVitals) {
  pulseOxLowPassRed.reset();
  pulseOxLowPassIr.reset();
  pulseOxHighPass.reset();
  pulseOxDifferentiator.reset();
  pulseOxHrAverage.reset();
  pulseOxSpo2Average.reset();
  pulseOxRedStat.reset();
  pulseOxIrStat.reset();
  lastHeartbeatMs = 0;
  lastCrossedMs = 0;
  lastDiff = NAN;
  crossed = false;
  fingerDetected = false;
  pulseOxBeatHistoryCount = 0;
  pulseOxBeatHistoryIndex = 0;
  for (size_t i = 0; i < MAX30102_STABILITY_WINDOW; ++i) {
    pulseOxBpmHistory[i] = 0;
    pulseOxSpo2History[i] = 0.0f;
  }

  if (clearVitals) {
    clearPulseOxVitals();
  }
}

bool initPulseOxSensor() {
  lastPulseOxInitAttemptMs = millis();
  Wire.setPins(MAX30102_SDA_PIN, MAX30102_SCL_PIN);
  Wire.begin(MAX30102_SDA_PIN, MAX30102_SCL_PIN);

  if (!pulseOxSensor.reset()) {
    Serial.println("[C3][MAX30102] init failed");
    return false;
  }

  if (!pulseOxSensor.setSamplingRate(pulseOxSensor.SAMPLING_RATE_100SPS)) {
    Serial.println("[C3][MAX30102] set sampling rate failed");
    return false;
  }

  if (!pulseOxSensor.setSampleAveraging(pulseOxSensor.SMP_AVE_4)) {
    Serial.println("[C3][MAX30102] set sample averaging failed");
    return false;
  }

  if (!pulseOxSensor.setLedCurrent(MAX30102::LED_RED, MAX30102_RED_LED_CURRENT) ||
      !pulseOxSensor.setLedCurrent(MAX30102::LED_IR, MAX30102_IR_LED_CURRENT)) {
    Serial.println("[C3][MAX30102] set LED current failed");
    return false;
  }

  pulseOxSensor.clearFIFO();
  resetPulseOxAlgorithm(true);
  Serial.println("[C3][MAX30102] ready");
  return true;
}

void initTemperatureSensor() {
  lastTempRescanMs = millis();
  pinMode(DS18B20_DQ_PIN, INPUT_PULLUP);
  delay(10);
  tempSensor.begin();
  uint8_t deviceCount = tempSensor.getDeviceCount();
  if (deviceCount == 0) {
    delay(50);
    tempSensor.begin();
    deviceCount = tempSensor.getDeviceCount();
  }

  ds18b20Ready = deviceCount > 0;
  if (!ds18b20Ready) {
    ds18b20ConversionPending = false;
    Serial.printf("[C3][DS18B20] not found on DQ=%d (deviceCount=%u)\n",
                  DS18B20_DQ_PIN,
                  (unsigned int)deviceCount);
    latestVitals.temp = NAN;
    return;
  }

  tempSensor.setResolution(12);
  tempSensor.setWaitForConversion(false);
  tempSensor.requestTemperatures();
  ds18b20ConversionPending = true;
  lastTempRequestMs = millis();
  Serial.printf("[C3][DS18B20] ready on DQ=%d (deviceCount=%u)\n",
                DS18B20_DQ_PIN,
                (unsigned int)deviceCount);
}

void initRealSensors() {
  pulseOxReady = initPulseOxSensor();
  initTemperatureSensor();
}

void updateTemperatureSensor() {
  uint32_t now = millis();
  if (!ds18b20Ready) {
    if ((now - lastTempRescanMs) >= TEMP_RESCAN_INTERVAL_MS) {
      Serial.println("[C3][DS18B20] retry init...");
      initTemperatureSensor();
    }
    return;
  }

  if (!ds18b20ConversionPending) {
    tempSensor.requestTemperatures();
    ds18b20ConversionPending = true;
    lastTempRequestMs = now;
    return;
  }

  if ((now - lastTempRequestMs) < TEMP_CONVERSION_MS) return;

  float tempC = tempSensor.getTempCByIndex(0);
  if (tempC > -100.0f && tempC < 125.0f && fabsf(tempC - 85.0f) > 0.01f) {
    latestVitals.temp = tempC;
  }

  if ((now - lastTempRequestMs) >= TEMP_READ_INTERVAL_MS) {
    tempSensor.requestTemperatures();
    lastTempRequestMs = now;
    ds18b20ConversionPending = true;
  } else {
    ds18b20ConversionPending = false;
  }
}

void updatePulseOxSensor() {
  if (!pulseOxReady) return;

  uint8_t sampleBudget = 32;
  while (sampleBudget-- > 0 && pulseOxSensor.available() > 0) {
    auto sample = pulseOxSensor.readSample();
    if (!sample.valid) break;

    float red = (float)sample.red;
    float ir = (float)sample.ir;
    const uint32_t now = millis();

    if (sample.red > MAX30102_FINGER_THRESHOLD && sample.ir > MAX30102_FINGER_THRESHOLD) {
      if ((now - fingerTimestampMs) > MAX30102_FINGER_COOLDOWN_MS) {
        fingerDetected = true;
      }
    } else {
      fingerTimestampMs = now;
      resetPulseOxAlgorithm(false);
      if (latestVitals.hr > 0 || latestVitals.spo2 > 0) {
        latestVitals.q = 15;
      }
      continue;
    }

    if (!fingerDetected) {
      latestVitals.q = 10;
      continue;
    }

    red = pulseOxLowPassRed.process(red);
    ir = pulseOxLowPassIr.process(ir);
    pulseOxRedStat.process(red);
    pulseOxIrStat.process(ir);

    // Use IR to detect pulse peaks; it is usually more stable than red on MAX30102.
    float filteredIr = pulseOxHighPass.process(ir);
    float currentDiff = pulseOxDifferentiator.process(filteredIr);

    if (!isnan(currentDiff) && !isnan(lastDiff)) {
      if (lastDiff > 0.0f && currentDiff < 0.0f) {
        crossed = true;
        lastCrossedMs = now;
      }

      if (currentDiff > 0.0f) {
        crossed = false;
      }

      if (crossed && currentDiff < MAX30102_EDGE_THRESHOLD) {
        if (lastHeartbeatMs != 0 && (lastCrossedMs - lastHeartbeatMs) > 300UL) {
          int bpm = (int)(60000UL / (lastCrossedMs - lastHeartbeatMs));
          float redAvg = pulseOxRedStat.average();
          float irAvg = pulseOxIrStat.average();
          float redRange = pulseOxRedStat.maximum() - pulseOxRedStat.minimum();
          float irRange = pulseOxIrStat.maximum() - pulseOxIrStat.minimum();

          if (bpm >= MAX30102_HR_MIN_BPM &&
              bpm <= MAX30102_HR_MAX_BPM &&
              redAvg >= MAX30102_RED_AVG_MIN &&
              irAvg >= MAX30102_IR_AVG_MIN &&
              redRange >= MAX30102_RED_RANGE_MIN &&
              irRange >= MAX30102_IR_RANGE_MIN) {
            float r = (redRange / redAvg) / (irRange / irAvg);
            float spo2 = (MAX30102_SPO2_A * r * r) + (MAX30102_SPO2_B * r) + MAX30102_SPO2_C;
            if (!isnan(spo2) && spo2 >= MAX30102_SPO2_MIN && spo2 <= MAX30102_SPO2_MAX) {
              float perfusionIndex = (irRange / irAvg) * 1000.0f;
              int baseQuality = clampQuality(35 + (int)(perfusionIndex * 2.5f) + ((int)pulseOxHrAverage.count() * 4));

              pulseOxBpmHistory[pulseOxBeatHistoryIndex] = bpm;
              pulseOxSpo2History[pulseOxBeatHistoryIndex] = spo2;
              pulseOxBeatHistoryIndex = (pulseOxBeatHistoryIndex + 1U) % MAX30102_STABILITY_WINDOW;
              if (pulseOxBeatHistoryCount < MAX30102_STABILITY_WINDOW) {
                pulseOxBeatHistoryCount++;
              }

              int stableBpm = 0;
              float stableSpo2 = NAN;
              if (pulseOxWindowStable(stableBpm, stableSpo2)) {
                float avgBpm = pulseOxHrAverage.process((float)stableBpm);
                float avgSpo2 = pulseOxSpo2Average.process(stableSpo2);
                if (pulseOxHrAverage.count() >= MAX30102_MIN_AVG_SAMPLES) {
                  latestVitals.hr = (int)roundf(avgBpm);
                  latestVitals.spo2 = (int)roundf(avgSpo2);
                }

                latestVitals.q = baseQuality;
                lastValidPulseOxMs = now;
              } else {
                latestVitals.q = min(MAX30102_MIN_REPORT_QUALITY - 1,
                                     clampQuality(baseQuality - 18));
                if (latestVitals.q < MAX30102_MIN_REPORT_QUALITY) {
                  latestVitals.hr = 0;
                  latestVitals.spo2 = 0;
                }
              }
            }
          }
          pulseOxRedStat.reset();
          pulseOxIrStat.reset();
        }

        crossed = false;
        lastHeartbeatMs = lastCrossedMs;
      }
    }

    lastDiff = currentDiff;
    if (latestVitals.q == 0) {
      latestVitals.q = 25;
    }
  }

  uint32_t now = millis();
  if (fingerDetected && lastHeartbeatMs != 0 && (now - lastHeartbeatMs) > MAX30102_HR_HOLD_MS) {
    if (lastValidPulseOxMs != 0 && (now - lastValidPulseOxMs) < MAX30102_VALUE_HOLD_MS) {
      latestVitals.q = 20;
    } else {
      clearPulseOxVitals();
    }
  }

  if (!fingerDetected && lastValidPulseOxMs != 0 && (now - lastValidPulseOxMs) >= MAX30102_VALUE_HOLD_MS) {
    clearPulseOxVitals();
  }
}

void updateRealSensors() {
  if (USE_FAKE_SENSOR_DATA) return;
  if (!pulseOxReady && (millis() - lastPulseOxInitAttemptMs) >= MAX30102_REINIT_INTERVAL_MS) {
    Serial.println("[C3][MAX30102] retry init...");
    pulseOxReady = initPulseOxSensor();
  }
  updatePulseOxSensor();
  updateTemperatureSensor();
}

void logRealVitalsIfNeeded() {
  if (USE_FAKE_SENSOR_DATA) return;

  uint32_t now = millis();
  if ((now - lastVitalsLogMs) < VITALS_LOG_INTERVAL_MS) return;
  lastVitalsLogMs = now;

  if (isnan(latestVitals.temp)) {
    Serial.printf("[C3][SENS] max=%s finger=%s hr=%d spo2=%d temp=nan q=%d\n",
                  pulseOxReady ? "OK" : "FAIL",
                  fingerDetected ? "true" : "false",
                  latestVitals.hr,
                  latestVitals.spo2,
                  latestVitals.q);
  } else {
    Serial.printf("[C3][SENS] max=%s finger=%s hr=%d spo2=%d temp=%.2f q=%d\n",
                  pulseOxReady ? "OK" : "FAIL",
                  fingerDetected ? "true" : "false",
                  latestVitals.hr,
                  latestVitals.spo2,
                  latestVitals.temp,
                  latestVitals.q);
  }
}

// ===================== REAL SENSOR SNAPSHOT =====================
bool readRealVitals(WristVitals& out) {
  out = latestVitals;
  out.sim = false;
  return pulseOxReady || ds18b20Ready;
}

WristVitals getCurrentVitals() {
  WristVitals v;
  if (USE_FAKE_SENSOR_DATA) {
    v = latestVitals;
    if (v.hr == 0 && v.spo2 == 0 && v.q == 0 && isnan(v.temp)) {
      v = generateFakeVitals();
    }
    return v;
  }

  readRealVitals(v);
  v.sim = false;
  if (!pulseOxReady) {
    v.hr = 0;
    v.spo2 = 0;
  } else if (v.q < MAX30102_MIN_REPORT_QUALITY) {
    v.hr = 0;
    v.spo2 = 0;
  }
  if (!ds18b20Ready) {
    v.temp = NAN;
  }
  return v;
}

void startMeasurementCycle() {
  measurementActive = true;
  sendPending = false;
  measurementStartedMs = millis();
  lastSendAttemptMs = 0;

  if (USE_FAKE_SENSOR_DATA) {
    latestVitals = generateFakeVitals();
    Serial.printf("[C3][FLOW] measurement armed hr=%d spo2=%d q=%d\n",
                  latestVitals.hr,
                  latestVitals.spo2,
                  latestVitals.q);
    return;
  }

  latestVitals.hr = 0;
  latestVitals.spo2 = 0;
  latestVitals.temp = NAN;
  latestVitals.q = 0;
  latestVitals.sim = false;

  resetPulseOxAlgorithm(true);

  if (ds18b20Ready) {
    tempSensor.requestTemperatures();
    ds18b20ConversionPending = true;
    lastTempRequestMs = measurementStartedMs;
  }

  Serial.println("[C3][FLOW] measurement armed");
}

bool measurementReadyToSend() {
  WristVitals v = getCurrentVitals();
  return v.hr > 0 && v.spo2 > 0 && v.q >= MAX30102_MIN_REPORT_QUALITY;
}

void lockMeasurementForSend(bool partialPacket = false) {
  WristVitals v = getCurrentVitals();
  measurementActive = false;
  sendPending = true;
  lastSendAttemptMs = 0;
  const char* lockReason = partialPacket ? "timeout-partial" : "ready";

  if (isnan(v.temp)) {
    Serial.printf("[C3][FLOW] measurement locked (%s) hr=%d spo2=%d temp=nan q=%d\n",
                  lockReason,
                  v.hr,
                  v.spo2,
                  v.q);
  } else {
    Serial.printf("[C3][FLOW] measurement locked (%s) hr=%d spo2=%d temp=%.2f q=%d\n",
                  lockReason,
                  v.hr,
                  v.spo2,
                  v.temp,
                  v.q);
  }
}

void clearFoundAdvDevice() {
  selectedGatewayAddrValid = false;
}

void cleanupClient() {
  if (bleClient != nullptr) {
    if (bleClient->isConnected()) {
      bleClient->disconnect();
    }
  }
  remoteWriteChar = nullptr;
}

void destroyClient() {
  if (bleClient != nullptr) {
    if (bleClient->isConnected()) {
      bleClient->disconnect();
      delay(40);
    }
    NimBLEDevice::deleteClient(bleClient);
    bleClient = nullptr;
  }
  remoteWriteChar = nullptr;
}

class ClientCB : public NimBLEClientCallbacks {
  void onConnect(NimBLEClient*) override {
    Serial.println("[C3][BLE] connected");
  }

  void onConnectFail(NimBLEClient*, int reason) override {
    Serial.printf("[C3][BLE] connect fail callback, reason=%d (%s)\n",
                  reason,
                  NimBLEUtils::returnCodeToString(reason));
  }

  void onDisconnect(NimBLEClient*, int reason) override {
    remoteWriteChar = nullptr;
    Serial.printf("[C3][BLE] disconnected, reason=%d\n", reason);
  }
};

static ClientCB clientCB;

bool ensureClient() {
  if (bleClient != nullptr) {
    return true;
  }

  bleClient = NimBLEDevice::createClient();
  if (bleClient == nullptr) {
    Serial.println("[C3][BLE] create client failed");
    return false;
  }

  bleClient->setClientCallbacks(&clientCB, false);
  bleClient->setConnectTimeout(BLE_CONNECT_TIMEOUT_MS);
  return true;
}

bool scanForGateway(uint32_t scanMs = 3000) {
  clearFoundAdvDevice();

  NimBLEScan* scan = NimBLEDevice::getScan();
  scan->stop();
  scan->clearResults();
  scan->setActiveScan(true);
  scan->setInterval(160);
  scan->setWindow(80);

  NimBLEScanResults results = scan->getResults(scanMs, false);
  for (int i = 0; i < results.getCount(); i++) {
    const NimBLEAdvertisedDevice* d = results.getDevice(i);
    if (d == nullptr) continue;

    bool nameMatch = d->haveName() && d->getName() == std::string(GATEWAY_NAME);
    bool svcMatch = d->isAdvertisingService(NimBLEUUID(SERVICE_UUID));
    bool cachedAddrMatch = cachedGatewayAddrValid && d->getAddress().equals(cachedGatewayAddr);

    Serial.printf(
      "[C3][SCAN] found name=%s addr=%s rssi=%d connectable=%s nameMatch=%s svcMatch=%s cachedMatch=%s\n",
      d->haveName() ? d->getName().c_str() : "(no-name)",
      d->getAddress().toString().c_str(),
      d->getRSSI(),
      d->isConnectable() ? "true" : "false",
      nameMatch ? "true" : "false",
      svcMatch ? "true" : "false",
      cachedAddrMatch ? "true" : "false"
    );

    if (!(nameMatch || svcMatch || cachedAddrMatch)) continue;
    if (!d->isConnectable()) continue;

    selectedGatewayAddr = d->getAddress();
    selectedGatewayAddrValid = true;
    if (nameMatch || svcMatch) {
      cachedGatewayAddr = d->getAddress();
      cachedGatewayAddrValid = true;
    }
    Serial.printf("[C3][SCAN] selected gateway addr=%s\n", selectedGatewayAddr.toString().c_str());
    return true;
  }

  scan->clearResults();
  return false;
}

bool connectToGateway() {
  if (!selectedGatewayAddrValid) return false;

  bool ok = false;
  for (uint8_t attempt = 1; attempt <= CONNECT_RETRY_COUNT; ++attempt) {
    destroyClient();
    if (!ensureClient()) break;
    delay(PRE_CONNECT_SETTLE_MS);

    Serial.printf("[C3][BLE] connecting to %s (attempt %u/%u)\n",
                  selectedGatewayAddr.toString().c_str(),
                  attempt,
                  CONNECT_RETRY_COUNT);

    ok = bleClient->connect(selectedGatewayAddr, true, false, true);
    if (ok) {
      break;
    }

    int lastErr = bleClient->getLastError();
    Serial.printf("[C3][BLE] connect failed, lastErr=%d (%s)\n",
                  lastErr,
                  NimBLEUtils::returnCodeToString(lastErr));
    destroyClient();
    delay(CONNECT_FAIL_BACKOFF_MS);
  }

  NimBLEDevice::getScan()->clearResults();
  clearFoundAdvDevice();

  if (!ok) {
    return false;
  }

  cachedGatewayAddr = bleClient->getPeerAddress();
  cachedGatewayAddrValid = true;

  NimBLERemoteService* svc = bleClient->getService(SERVICE_UUID);
  if (svc == nullptr) {
    Serial.println("[C3][BLE] service not found");
    cleanupClient();
    return false;
  }

  remoteWriteChar = svc->getCharacteristic(WRITE_CHAR_UUID);
  if (remoteWriteChar == nullptr) {
    Serial.println("[C3][BLE] write char not found");
    cleanupClient();
    return false;
  }

  if (!(remoteWriteChar->canWrite() || remoteWriteChar->canWriteNoResponse())) {
    Serial.println("[C3][BLE] write char not writable");
    cleanupClient();
    return false;
  }

  Serial.println("[C3][BLE] gateway ready");
  return true;
}

bool findAndConnectGateway() {
  Serial.println("[C3][BLE] scanning...");
  if (!scanForGateway(SCAN_WINDOW_MS)) {
    Serial.println("[C3][BLE] gateway not found");
    return false;
  }

  return connectToGateway();
}

bool sendPacketToGateway() {
  if (!(bleClient != nullptr && bleClient->isConnected() && remoteWriteChar != nullptr)) {
    return false;
  }

  WristVitals v = getCurrentVitals();

  StaticJsonDocument<160> doc;
  doc["hr"] = v.hr;
  doc["spo2"] = v.spo2;
  doc["temp"] = v.temp;
  doc["q"] = v.q;
  doc["sim"] = v.sim;

  String body;
  serializeJson(doc, body);

  bool ok = remoteWriteChar->writeValue((uint8_t*)body.c_str(), body.length(), true);
  Serial.printf("[C3][TX] %s -> %s\n", ok ? "write OK" : "write FAIL", body.c_str());
  return ok;
}

// ===================== SETUP / LOOP =====================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("ESP32-C3 wrist client start (NimBLE, no-seq)");

  esp_reset_reason_t reason = esp_reset_reason();
  Serial.printf("[BOOT] reset reason=%d (%s)\n", (int)reason, resetReasonText(reason));

  initRealSensors();

  NimBLEDevice::init("wrist-central");
  NimBLEDevice::setPower(9);
  NimBLEDevice::setMTU(247);

  startMeasurementCycle();
}

void loop() {
  uint32_t now = millis();
  if (measurementActive) {
    updateRealSensors();
    if (measurementReadyToSend()) {
      lockMeasurementForSend(false);
    } else if ((now - measurementStartedMs) >= MAX30102_MEASUREMENT_TIMEOUT_MS) {
      Serial.println("[C3][FLOW] measurement timeout, sending partial packet");
      lockMeasurementForSend(true);
    }
  }
  if (measurementActive || sendPending) {
    logRealVitalsIfNeeded();
  }

  if (!measurementActive && !sendPending && (now - lastSendMs >= SEND_INTERVAL_MS)) {
    startMeasurementCycle();
  }

  if (sendPending) {
    if ((now - lastSendAttemptMs) >= SEND_RETRY_BACKOFF_MS) {
      lastSendAttemptMs = now;
      bool sent = false;

      if (findAndConnectGateway()) {
        sent = sendPacketToGateway();
      }

      destroyClient();
      delay(POST_DISCONNECT_DELAY_MS);
      NimBLEDevice::getScan()->clearResults();
      clearFoundAdvDevice();

      if (sent) {
        lastSendMs = millis();
        sendPending = false;
        Serial.println("[C3][FLOW] send complete, waiting for next cycle");
      } else {
        Serial.println("[C3][FLOW] send attempt failed, backing off");
      }
    }
  }

  if (now - lastAliveMs >= 5000UL) {
    lastAliveMs = now;
    const char* mode = measurementActive ? "measure-lock" : (sendPending ? "send-locked" : "wait-next-cycle");
    Serial.printf("[C3][ALIVE] mode=%s\n", mode);
  }

  delay(20);
}
