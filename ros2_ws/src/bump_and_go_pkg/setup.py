# setup.py
from setuptools import setup

package_name = 'bump_and_go_pkg'

setup(
    name=package_name,
    version='0.0.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # Añadimos esta línea para incluir nuestros archivos de lanzamiento
        ('share/' + package_name + '/launch', ['launch/start_demo.launch.py']),
        # Y estas para los mundos y modelos
#        ('share/' + package_name + '/worlds', ['worlds/obstacles.world.sdf']),
      #  ('share/' + package_name + '/models', ['models/robot.sdf']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='tu_nombre',
    maintainer_email='tu_email@example.com',
    description='Demo simple de Bump and Go en ROS 2',
    license='Apache License 2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            # Esto hace que 'driver' sea un ejecutable que corre nuestro script
            'driver = bump_and_go_pkg.driver:main',
        ],
    },
)
