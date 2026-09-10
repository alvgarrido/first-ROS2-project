import sys
if sys.prefix == '/usr':
    sys.real_prefix = sys.prefix
    sys.prefix = sys.exec_prefix = '/home/algarrid/first-ROS2-project/src/install/bump_and_go_pkg'
