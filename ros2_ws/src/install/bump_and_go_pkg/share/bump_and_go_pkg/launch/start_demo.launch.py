# launch/start_demo.launch.py
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import ExecuteProcess, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node

def generate_launch_description():
    pkg_share = get_package_share_directory('bump_and_go_pkg')
    
    # 1. Lanzar Gazebo con nuestro mundo
    world_path = os.path.join(pkg_share, 'worlds', 'obstacles.world')
    gazebo = ExecuteProcess(
        cmd=['gazebo', '--verbose', '-s', 'libgazebo_ros_init.so', '-s', 'libgazebo_ros_factory.so', world_path],
        output='screen'
    )
    
    # 2. "Invocar" (spawn) nuestro robot en Gazebo
    robot_sdf_path = os.path.join(pkg_share, 'models', 'robot.sdf')
    spawn_entity = Node(
        package='gazebo_ros',
        executable='spawn_entity.py',
        arguments=['-entity', 'simple_bot', '-file', robot_sdf_path, '-x', '0', '-y', '0', '-z', '0.2'],
        output='screen'
    )

    # 3. Lanzar RViz2 para visualización
    rviz2 = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        output='screen'
    )

    # 4. Lanzar nuestro nodo "cerebro"
    bump_and_go_node = Node(
        package='bump_and_go_pkg',
        executable='driver', # El nombre que le dimos en setup.py
        name='bump_and_go_driver',
        output='screen'
    )

    return LaunchDescription([
        gazebo,
        spawn_entity,
        rviz2,
        bump_and_go_node,
    ])
