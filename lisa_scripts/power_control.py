#
# THU - Team Oriented Project - WS20/21
#
"""
The power controller for the Jetson Nanos.
"""
from time import sleep
import sys

import RPi.GPIO as GPIO

"""
Pin mapping for power and reset cycle.
"""
gpio_power = {1: 11, 2: 13, 3: 16, 4: 22, 5: 31, 6: 33, 7: 36, 8: 38}
gpio_reset = {1: 12, 2: 15, 3: 18, 4: 29, 5: 32, 6: 35, 7: 37, 8: 40}

class PowerControl:
    """
    Controls the relays (active low) through the GPIO pins of the system controller.
    """
    def power_cycle(self, node_number):
        GPIO.setmode(GPIO.BOARD)
        GPIO.setup(gpio_power[node_number], GPIO.OUT)
        GPIO.output(gpio_power[node_number], GPIO.HIGH)
        try:
            GPIO.output(gpio_power[node_number], GPIO.LOW)
            sleep(0.5)
            GPIO.output(gpio_power[node_number], GPIO.HIGH)
        except:
            print("Pin number " + str(gpio_power[node_number]) + " couldn't be turned on")
        GPIO.cleanup()
        sleep(0.5)

    def reset_cycle(self, node_number):
        GPIO.setmode(GPIO.BOARD)
        GPIO.setup(gpio_reset[node_number], GPIO.OUT)
        GPIO.output(gpio_reset[node_number], GPIO.HIGH)
        try:
            GPIO.output(gpio_reset[node_number], GPIO.LOW)
            sleep(0.5)
            GPIO.output(gpio_reset[node_number], GPIO.HIGH)
        except:
            print("Pin number " + str(gpio_reset[node_number]) + " couldn't be turned on")
        GPIO.cleanup()
        sleep(0.5)

"""
The following part is to access the program through console i.e. "python3 power_control.py power 1" and to handle possible user input errors.
"""

def error_usage():
    print("\n*********************************************\n** Power and Reset Control of Jetson Nanos **\n*********************************************")
    print("Usage:\n - First Argument: [power] or [reset]\n - Second Argument: [1] to [8]\n\ni.e. \"python3 power_control.py reset 1\"\n")
    sys.exit(1)

def error_arguments():
    print("Expecting exactly two arguments!\n([h] for help)")
    sys.exit(1)

def error_mode():
    print("Mode has to be power/reset\n([h] for help)")
    sys.exit(1)

def error_number():
    print("Node number is expected to be an integer between 1 and 8!\n([h] for help)")
    sys.exit(1)

if len(sys.argv) == 1:
    error_usage()

mode = sys.argv[1]

if len(sys.argv) == 2:
    if mode in ["h", "help", "-h", "-help", "--h", "--help"]:
        error_usage()
    else:
        error_arguments()

if len(sys.argv) > 3:
    error_arguments()

node_num = sys.argv[2]

if mode not in ["power","reset"]:
    error_mode()

try:
    node_num = int(node_num)
    if node_num not in range(1,9):
        error_number()
except ValueError:
    error_number()

if mode == "power":
    PowerControl().power_cycle(node_num)
elif mode == "reset":
    PowerControl().reset_cycle(node_num)
else:
    print("Unknown error")
    sys.exit(1)