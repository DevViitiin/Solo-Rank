import 'package:flutter/material.dart';
import 'dart:math' as math;


/// Fundo animado com partículas flutuantes via [CustomPaint].
///
/// Renderiza [particleCount] partículas que se movem para baixo
/// continuamente, configuráveis em tamanho, opacidade e velocidade.
/// Usa [AnimationController] com repeat para atualizar o canvas.
class AnimatedParticlesBackground extends StatefulWidget {
  final Widget child;
  final Color particleColor;
  final int particleCount;
  final double minSize;
  final double maxSize;
  final double minOpacity;
  final double maxOpacity;
  final double minSpeed;
  final double maxSpeed;
  
  const AnimatedParticlesBackground({
    Key? key,
    required this.child,
    required this.particleColor,
    this.particleCount = 30,
    this.minSize = 1.0,
    this.maxSize = 4.0,
    this.minOpacity = 0.1,
    this.maxOpacity = 0.3,
    this.minSpeed = 0.1,
    this.maxSpeed = 0.5,
  }) : super(key: key);
  
  @override
  State<AnimatedParticlesBackground> createState() => 
      _AnimatedParticlesBackgroundState();
}

class _AnimatedParticlesBackgroundState 
    extends State<AnimatedParticlesBackground> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late List<Particle> _particles;
  
  @override
  void initState() {
    super.initState();
    _generateParticles();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }
  
  /// Gera lista de partículas com posições e tamanhos aleatórios.
  void _generateParticles() {
    final random = math.Random();
    _particles = List.generate(
      widget.particleCount,
      (index) => Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: widget.minSize + random.nextDouble() * (widget.maxSize - widget.minSize),
        speed: widget.minSpeed + random.nextDouble() * (widget.maxSpeed - widget.minSpeed),
        opacity: widget.minOpacity + random.nextDouble() * (widget.maxOpacity - widget.minOpacity),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Partículas animadas
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlesPainter(
                  particles: _particles,
                  animation: _controller.value,
                  color: widget.particleColor,
                ),
              );
            },
          ),
        ),
        
        // Conteúdo
        widget.child,
      ],
    );
  }
}

/// Modelo de dados de uma partícula individual.
///
/// Armazena posição (x, y normalizado 0-1), tamanho, velocidade e opacidade.
class Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  
  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

/// [CustomPainter] que desenha partículas como círculos no canvas.
///
/// Atualiza a posição Y de cada partícula a cada frame para simular
/// movimento descendente contínuo com wrap-around.
class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;
  final Color color;
  
  ParticlesPainter({
    required this.particles,
    required this.animation,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final particle in particles) {
      // Atualizar posição Y (movimento para baixo)
      particle.y = (particle.y + particle.speed * 0.005) % 1.0;
      
      final x = particle.x * size.width;
      final y = particle.y * size.height;
      
      paint.color = color.withOpacity(particle.opacity);
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) => true;
}
