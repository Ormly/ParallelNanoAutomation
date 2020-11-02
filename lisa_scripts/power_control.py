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

should_print = True

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
            if should_print:
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
            if should_print:
                print("Pin number " + str(gpio_power[node_number]) + " couldn't be turned on")
        GPIO.cleanup()
        sleep(0.5)

"""
The following part is to access the program through console i.e. "python3 power_control.py power 1 noprint" and to handle possible user input errors.
"""

def error_usage():
    if should_print:
        print("\n*********************************************\n** Power and Reset Control of Jetson Nanos **\n*********************************************")
        print("Usage:\n - First Argument: [power] or [reset]\n - Second Argument: [1] to [8]\n - Third Argument: empty or [noprint]\n\ni.e. \"python3 power_control.py reset 1 noprint\"\n")
    sys.exit(1)

def error_arguments():
    if should_print:
        print("Expecting two to three arguments!\n([h] for help)")
    sys.exit(1)

def error_mode():
    if should_print:
        print("Mode has to be power/reset\n([h] for help)")
    sys.exit(1)

def error_number():
    if should_print:
        print("Node number is expected to be an integer between 1 and 8!\n([h] for help)")
    sys.exit(1)

def error_unknown():
    if should_print:
        print("Unknown error")
    sys.exit(1)

if "noprint" in sys.argv:
    should_print = False

if len(sys.argv) == 1:
    error_usage()

if len(sys.argv) > 1:
    mode = sys.argv[1]
    if mode in ["h", "help", "-h", "-help", "--h", "--help"]:
        error_usage()
    elif mode not in ["power","reset"]:
        error_mode()
    elif len(sys.argv) < 3:
        error_arguments()

if len(sys.argv) > 2:
    node_num = sys.argv[2]
    if node_num not in ["1", "2", "3", "4", "5", "6", "7", "8"]:
        error_number()
    else:
        node_num = int(node_num)

if len(sys.argv) > 3:
    disable_print = sys.argv[3]
    if disable_print not in ["noprint", "-noprint", "--noprint"]:
        error_usage()

if len(sys.argv) > 4:
    error_arguments()

if mode == "power":
    PowerControl().power_cycle(node_num)
elif mode == "reset":
    PowerControl().reset_cycle(node_num)
else:
    error_unknown()
