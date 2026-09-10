# bump_and_go_pkg/driver.py
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist       # Para enviar comandos de velocidad
from sensor_msgs.msg import LaserScan     # Para recibir datos del láser
import time

class BumpAndGoNode(Node):
    def __init__(self):
        super().__init__('bump_and_go_node')
        
        # Crear un publisher para enviar comandos de velocidad al robot
        self.publisher_ = self.create_publisher(Twist, 'cmd_vel', 10)
        
        # Crear un subscriber para recibir datos del sensor láser
        self.subscriber_ = self.create_subscription(
            LaserScan,
            'scan',
            self.laser_callback,
            10)
        
        # Estado del robot: 0 = avanzando, 1 = girando
        self.robot_state = 0
        self.get_logger().info('Nodo Bump and Go iniciado. ¡Vamos allá!')

    def laser_callback(self, msg):
        # La lógica principal del robot
        
        # El mensaje Twist es lo que usaremos para mover al robot
        twist_msg = Twist()
        
        # El sensor láser nos da un array de distancias (ranges)
        # Queremos mirar solo lo que está justo en frente del robot.
        # El láser tiene 360 muestras, el frente es la muestra 0 (o 359).
        # Vamos a comprobar un pequeño arco frontal para ser más robustos.
        distancia_frontal = msg.ranges[0]
        
        # Distancia umbral para considerar un obstáculo
        umbral_distancia = 0.6  # en metros
        
        # --- Lógica de decisión ---
        
        # Estado 0: Avanzar hasta encontrar un obstáculo
        if self.robot_state == 0:
            self.get_logger().info(f'Avanzando. Distancia frontal: {distancia_frontal:.2f}m')
            twist_msg.linear.x = 0.2  # Velocidad hacia adelante
            twist_msg.angular.z = 0.0 # Sin rotación
            
            if distancia_frontal < umbral_distancia:
                # ¡Obstáculo detectado! Cambiamos al estado de giro
                self.robot_state = 1
                self.get_logger().info('¡Obstáculo! Cambiando a estado de giro.')
        
        # Estado 1: Girar hasta que el camino esté despejado
        elif self.robot_state == 1:
            self.get_logger().info(f'Girando. Distancia frontal: {distancia_frontal:.2f}m')
            twist_msg.linear.x = 0.0  # Detenemos el avance
            twist_msg.angular.z = 0.5  # Velocidad de giro (radianes/seg)
            
            if distancia_frontal >= umbral_distancia:
                # ¡Camino despejado! Volvemos al estado de avance
                self.robot_state = 0
                self.get_logger().info('Camino despejado. Cambiando a estado de avance.')
                
        # Publicamos el mensaje de velocidad para que el robot se mueva
        self.publisher_.publish(twist_msg)

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
