import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';

/// App Bar superior (designer.md §8.2): 64 dp + safe area, `surface` al 80 %
/// con blur 24, marca + título de sección a la izquierda y avatar de perfil a
/// la derecha. [onCatalogTap] añade el acceso al catálogo solo donde aplica
/// (RF-10 de la 008: header de Entrenar).
PreferredSize hevyAppBar(
  BuildContext context, {
  required String title,
  required VoidCallback onProfileTap,
  VoidCallback? onCatalogTap,
}) {
  final textTheme = Theme.of(context).textTheme;
  final topInset = MediaQuery.of(context).padding.top;
  final height = topInset + 64;

  return PreferredSize(
    preferredSize: Size.fromHeight(height),
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: height,
            color: kSurface.withValues(alpha: 0.8),
            padding: EdgeInsets.only(top: topInset, left: 16, right: 8),
            child: Row(
              children: [
                Semantics(
                  header: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 32,
                        fit: BoxFit.contain,
                        semanticLabel: 'HevyWork',
                        key: Key('app-bar-logo'),
                      ),
                      SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 1,
                          height: 16,
                          color: kOutlineVariant,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.headlineSmall
                              ?.copyWith(color: kPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (onCatalogTap != null) ...[
                  Semantics(
                    label: 'Catálogo de ejercicios',
                    button: true,
                    child: InkWell(
                      onTap: onCatalogTap,
                      borderRadius: BorderRadius.circular(12),
                      highlightColor: kSurfaceContainerHigh,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            Icons.search,
                            size: 22,
                            color: kOnSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Semantics(
                  label: 'Perfil',
                  button: true,
                  child: InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(12),
                    highlightColor: kSurfaceContainerHigh,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: kSurfaceContainerHighest,
                          child: Icon(
                            Icons.person,
                            size: 18,
                            color: kOnSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
