import 'package:flutter/material.dart';
import 'dart:math';

class ParticleBackground extends StatefulWidget {
  final bool isDarkMode;

  const ParticleBackground({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  _ParticleBackgroundState createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  Offset _mousePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
      setState(() {
        _particles.forEach((p) => p.update(MediaQuery.of(context).size));
      });
    })..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initParticles();
    });
  }

  void _initParticles() {
    final size = MediaQuery.of(context).size;
    final particleCount = (size.width / 35).floor();
    for (int i = 0; i < particleCount; i++) {
      _particles.add(Particle(size, widget.isDarkMode));
    }
  }

  @override
  void didUpdateWidget(ParticleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      for (var particle in _particles) {
        particle.updateTheme(widget.isDarkMode);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        setState(() {
          _mousePosition = event.localPosition;
        });
      },
      onExit: (event) {
        setState(() {
          _mousePosition = Offset.zero;
        });
      },
      child: CustomPaint(
        painter: ParticlePainter(_particles, _mousePosition, widget.isDarkMode),
        child: Container(),
      ),
    );
  }
}

class Particle {
  late Offset position;
  late double speedX, speedY, size;
  late Color primaryColor;
  late Color secondaryColor;
  bool isDarkMode;

  Particle(Size canvasSize, this.isDarkMode) {
    Random random = Random();
    position = Offset(
      random.nextDouble() * canvasSize.width,
      random.nextDouble() * canvasSize.height,
    );
    size = random.nextDouble() * 2 + 1;
    speedX = random.nextDouble() * 0.8 - 0.4;
    speedY = random.nextDouble() * 0.8 - 0.4;
    _updateColors();
  }

  void _updateColors() {
    if (isDarkMode) {
      // Couleurs pour le mode sombre
      primaryColor = const Color(0x80388BFD); // Bleu
      secondaryColor = const Color(0xA3A371F7); // Violet
    } else {
      // Couleurs pour le mode clair
      primaryColor = const Color(0x80388BFD).withOpacity(0.6); // Bleu plus clair
      secondaryColor = const Color(0xA3A371F7).withOpacity(0.6); // Violet plus clair
    }
  }

  void updateTheme(bool newIsDarkMode) {
    isDarkMode = newIsDarkMode;
    _updateColors();
  }

  void update(Size canvasSize) {
    position = Offset(position.dx + speedX, position.dy + speedY);

    if (position.dx < 0 || position.dx > canvasSize.width) {
      speedX = -speedX;
    }
    if (position.dy < 0 || position.dy > canvasSize.height) {
      speedY = -speedY;
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Offset mousePosition;
  final bool isDarkMode;

  ParticlePainter(this.particles, this.mousePosition, this.isDarkMode);

  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner le fond adaptatif
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDarkMode
            ? [
          const Color(0xFF0D1117),
          const Color(0xFF161B22),
          const Color(0xFF0A0D12),
        ]
            : [
          const Color(0xFFF8F9FA),
          const Color(0xFFE9ECEF),
          const Color(0xFFDEE2E6),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Dessiner les particules avec leurs couleurs adaptatives
    for (var p in particles) {
      final particlePaint = Paint()..color = p.primaryColor;
      canvas.drawCircle(p.position, p.size, particlePaint);
    }

    // Dessiner les connexions entre particules
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final dist = (particles[i].position - particles[j].position).distance;
        if (dist < 120) {
          final opacity = (1 - (dist / 120)) * (isDarkMode ? 0.8 : 0.4);
          final linePaint = Paint()
            ..color = particles[i].primaryColor.withOpacity(opacity)
            ..strokeWidth = 0.5;
          canvas.drawLine(particles[i].position, particles[j].position, linePaint);
        }
      }
    }

    // Dessiner les connexions avec la souris (mode sombre uniquement ou plus discret en mode clair)
    if (mousePosition != Offset.zero) {
      for (var p in particles) {
        final dist = (p.position - mousePosition).distance;
        if (dist < 250) {
          final opacity = (1 - (dist / 250)) * (isDarkMode ? 0.6 : 0.3);
          final linePaint = Paint()
            ..color = p.secondaryColor.withOpacity(opacity)
            ..strokeWidth = isDarkMode ? 1.0 : 0.5;
          canvas.drawLine(p.position, mousePosition, linePaint);
        }
      }

      // Dessiner un effet de halo autour de la souris en mode sombre
      if (isDarkMode) {
        final haloPaint = Paint()
          ..color = const Color(0xA3A371F7).withOpacity(0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
        canvas.drawCircle(mousePosition, 30, haloPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
