import 'package:flutter/material.dart';

// Shared async UI widgets: loading, error, empty, and a generic AsyncBuilder

class AsyncLoadingWidget extends StatelessWidget {
  final String? message;
  const AsyncLoadingWidget({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[const SizedBox(height: 12), Text(message!)],
        ],
      ),
    );
  }
}

class CompactLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const CompactLoadingIndicator({Key? key, this.size = 16, this.color})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final indicatorColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: indicatorColor),
    );
  }
}

class AsyncErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  const AsyncErrorWidget({Key? key, required this.error, this.onRetry})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (onRetry != null)
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class AsyncEmptyWidget extends StatelessWidget {
  final String message;
  const AsyncEmptyWidget({Key? key, this.message = 'Nothing here yet'})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// A convenience wrapper for FutureBuilder that wires up shared UI states.
class AsyncBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext, T) onData;
  final Widget? loading;
  final Widget Function(BuildContext, Object)? onError;
  final Widget? empty;

  const AsyncBuilder({
    Key? key,
    required this.future,
    required this.onData,
    this.loading,
    this.onError,
    this.empty,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const AsyncLoadingWidget();
        }
        if (snapshot.hasError) {
          if (onError != null) return onError!(context, snapshot.error!);
          return AsyncErrorWidget(error: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return empty ?? const AsyncEmptyWidget();
        }
        return onData(context, snapshot.data as T);
      },
    );
  }
}
