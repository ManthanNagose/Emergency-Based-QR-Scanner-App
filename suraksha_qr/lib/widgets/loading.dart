// Loading and status widgets
import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const AppLoading({
    super.key,
    this.message,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? theme.colorScheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: AppLoading(message: message),
          ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isVerified;

  const StatusBadge({
    super.key,
    required this.status,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    switch (status.toLowerCase()) {
      case 'verified':
        backgroundColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
        icon = Icons.verified;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange[800]!;
        icon = Icons.hourglass_empty;
        break;
      case 'rejected':
        backgroundColor = theme.colorScheme.errorContainer;
        textColor = theme.colorScheme.onErrorContainer;
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  final bool verified;
  final double size;

  const VerifiedBadge({
    super.key,
    required this.verified,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(
      verified ? Icons.verified : Icons.verified_outlined,
      color: verified ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      size: size,
    );
  }
}