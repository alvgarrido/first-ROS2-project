# bump_and_go_pkg/driver.py
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist       # To send velocity commands
from sensor_msgs.msg import LaserScan     # To receive laser data
import time
import math

class BumpAndGoNode(Node):
    def __init__(self):
        super().__init__('bump_and_go_node')
        
        # Create a publisher to send velocity commands to the robot
        self.publisher_ = self.create_publisher(Twist, 'cmd_vel', 10)
        
        # Create a subscriber to send laser data
        self.subscriber_ = self.create_subscription(
            LaserScan,
            'scan',
            self.laser_callback,
            10)
        
        # Robot state: 0 = moving forward, 1 = turning
        self.robot_state = 0
        self.get_logger().info('Nodo Bump and Go initiated!')

    def laser_callback(self, msg):
        # The main logic of the robot
        
        # The twist message to move the robot
        twist_msg = Twist()
        
        # Threshold distance at which obstacle is considered to be detected 
        threshold_distance = 0.6  # meters
        
        # The laser sensor gives us an array of distances
        # We want to look only those distances that are just in front
        # The laser has 360 degrees, and zero is in front.
        #min_frontal_distance = msg.ranges[0]
        
        # Threshold distance at which obstacle is considered to be detected 
        threshold_distance = 0.6  # meters
        
        # The laser sensor gives us an array of distances
        # The laser has 360 degrees, and zero is in front. 
        # Calculate the number of laser samples in our desired arc.

        arc_angle_rad = 0.3
        num_samples_in_arc_side = int(arc_angle_rad / msg.angle_increment)

        # The arc consists of samples from the beginning of the array (for positive angles)
        # and from the end of the array (for negative angles, which wrap around).
        # Slice for [0, +0.3 rad]
        arc_positive = msg.ranges[0 : num_samples_in_arc_side + 1]
        # Slice for [-0.3 rad, 0)
        arc_negative = msg.ranges[-num_samples_in_arc_side : ]
        
        # Combine the slices to form the full frontal arc
        frontal_arc_ranges = arc_positive + arc_negative

        # Filter out 'inf' (infinity) and 'nan' (not a number) values,
        # which can occur if the laser doesn't detect a return.
        valid_ranges = [r for r in frontal_arc_ranges if not (math.isinf(r) or math.isnan(r))]

        # Find the minimum distance in the valid range list.
        # If the list is empty (e.g., all readings were 'inf'), we assume the path is clear.
        if not valid_ranges:
            min_frontal_distance = float('inf') # Treat as clear path
        else:
            min_frontal_distance = min(valid_ranges)
            
        
        # --- Decision logic ---
        
        # State 0: Move forward until an obstacle is found
        if self.robot_state == 0:
            self.get_logger().info(f'Moving forwardOMG. Min frontal distance: {min_frontal_distance:.2f}m')
            twist_msg.linear.x = 0.4  # Speed moving forward
            twist_msg.angular.z = 0.0 # No rotation
            
            if min_frontal_distance < threshold_distance:
                # Obstacle detected! Change state to turning
                self.robot_state = 1
                
                # MODIFICATION: Record the time when the turn begins
                self.turn_start_time = time.time()
                
                self.get_logger().info('Obstacle detected! Starting 2-second turn.')
        
        # State 1: Rotate for 2 seconds
        elif self.robot_state == 1:
            self.get_logger().info('Rotating...')
            twist_msg.linear.x = 0.0  # Stop forward movement
            twist_msg.angular.z = 0.5  # Rotational speed (radians/sec)
            
            # Check if 2 seconds have passed since the turn started
            current_time = time.time()
            if current_time - self.turn_start_time >= 2.0:
                # Time is up! Go back to moving forward
                self.robot_state = 0
                self.turn_start_time = None # Reset the timer
                self.get_logger().info('Turn complete. Resuming forward movement.')
                
        # Publish the velocity message for the robot to move
        self.publisher_.publish(twist_msg)
        
        """
         # --- Lógica de decisión ---
        # State 1: Move forward until I no longer find an obstacle
        if self.robot_state == 0:
            self.get_logger().info(f'Moving forward. Frontal distance: {distancia_frontal:.2f}m')
            twist_msg.linear.x = 0.1  # Speed moving forward
            twist_msg.angular.z = 0.0 # No rotation
            
            if distancia_frontal < threshold_distance:
                # Obstacle detected! Rotate the robot
                self.robot_state = 1
                self.get_logger().info('Obstacle detected! Change direction.')
        
        # State 1: Rotate for 2 seconds
        elif self.robot_state == 1:
            self.get_logger().info(f'Rotating. Frontal distance: {distancia_frontal:.2f}m')
            twist_msg.linear.x = 0.0  # Detenemos el avanc
            twist_msg.angular.z = 0.5  # Velocidad de giro (radianes/seg)
            
            if distancia_frontal >= threshold_distance:
                # ¡Camino despejado! Volvemos al estado de avance
                self.robot_state = 0
                self.get_logger().info('Camino despejado. Cambiando a estado de avance.')
                
        # Publish the velocity message so that the Robot moves
        self.publisher_.publish(twist_msg)
	"""
	
def main(args=None):
    rclpy.init(args=args)
    node = BumpAndGoNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
