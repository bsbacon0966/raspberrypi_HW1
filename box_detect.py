import time
import board
import busio
import adafruit_lsm9ds0
import firebase_admin
from firebase_admin import credentials, firestore
import RPi.GPIO as GPIO
from datetime import datetime

# GPIO 引腳和 PWM 設定
LED_PIN = 13
PWM_FREQ = 200

# 初始化 GPIO
GPIO.setmode(GPIO.BCM)
GPIO.setup(LED_PIN, GPIO.OUT)
pwm = GPIO.PWM(LED_PIN, PWM_FREQ)
pwm.start(0)

# 初始化 Firebase 憑證
cred = credentials.Certificate("/home/pi/raspberryAccountKey.json")
firebase_admin.initialize_app(cred)

# 連接到 Firestore
db = firestore.client()

# I2C 连接到传感器
i2c = busio.I2C(board.SCL, board.SDA)
sensor = adafruit_lsm9ds0.LSM9DS0_I2C(i2c)  # 确保在这里定义 sensor

# 全局變數
z_threshold = 5.0  # 初始值
box_state = False  # 盒子狀態

# 得到sensor的資料
def get_sensor_data():
    accel_x, accel_y, accel_z = sensor.acceleration  # 这里可以访问 sensor
    mag_x, mag_y, mag_z = sensor.magnetic
    gyro_x, gyro_y, gyro_z = sensor.gyro
    temp = sensor.temperature
    
    data = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'acceleration': {
            'x': accel_x,
            'y': accel_y,
            'z': accel_z
        },
        'magnetic': {
            'x': mag_x,
            'y': mag_y,
            'z': mag_z
        },
        'gyro': {
            'x': gyro_x,
            'y': gyro_y,
            'z': gyro_z
        },
        'temperature': temp
    }
    return data

def send_data_to_firebase():
    time_data = {'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
    db.collection('devices').add(time_data)

# 加亮度
def increase_brightness():
    for duty_cycle in range(0, 50, 2):
        pwm.ChangeDutyCycle(duty_cycle)
        time.sleep(0.1)

# 減亮度
def decrease_brightness():
    for duty_cycle in range(50, -1, -2):
        pwm.ChangeDutyCycle(duty_cycle)
        time.sleep(0.1)

# 監聽 Firebase 中的 Z_THRESHOLD 變更
def listen_for_threshold_updates():
    def on_snapshot(doc_snapshot, changes, read_time):
        global z_threshold  # 宣告使用全局變數
        for doc in doc_snapshot:
            new_threshold = doc.get('Z_THRESHOLD')
            if new_threshold is not None:
                z_threshold = new_threshold  # 更新全局閾值
                print(f'Z_THRESHOLD updated: {z_threshold}')
    
    doc_ref = db.collection('settings').document('thresholds')
    doc_ref.on_snapshot(on_snapshot)

if __name__ == "__main__":
    print('Starting')
    listen_for_threshold_updates()  
    
    try:
        while True:
            sensor_data = get_sensor_data()
            current_accel_z = sensor_data['acceleration']['z']
            
            # 使用全局變數中的閾值
            if current_accel_z < z_threshold and current_accel_z > -16 and not box_state:
                box_state = True
                send_data_to_firebase()
                increase_brightness()
                print(f"Current Z: {current_accel_z}")
                print(f"Current threshold: {z_threshold}")
                print("The box has been opened!!")
            elif current_accel_z >= 8 and box_state:
                box_state = False
                print("The box has been closed!!")
                decrease_brightness()
            
            time.sleep(0.1)  # 添加小延遲以減少 CPU 使用率
            
    except KeyboardInterrupt:
        print('Closed')
    finally:
        pwm.stop()
        GPIO.cleanup()
