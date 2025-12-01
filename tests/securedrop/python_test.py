from testapi import *

def run(self):
    perl.require('x11utils')
    print("Running python in perl test module!")
    x11_start_program('xterm')
    sleep(20) # Just to see the final result
