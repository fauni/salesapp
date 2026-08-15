import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/items/items_bloc.dart';
import '../../data/models/customer.dart';
import '../../data/models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/elevated_search_bar.dart';
import '../widgets/status_message.dart';
import 'widgets/cart_pill.dart';
import 'widgets/item_grid_tile.dart';
import 'widgets/item_tile.dart';
import 'widgets/line_config_sheet.dart';

/// New order — step 2: item catalog. Search + infinite scroll, tap an item to
/// configure its line, floating cart pill to review the in-progress order.
class ItemCatalogScreen extends StatefulWidget {
  final Customer customer;

  /// Route the floating cart pill pushes to review the order. Defaults to the
  /// normal new-order summary; "Duplicar pedido" passes its own summary route
  /// so the pill stays inside that flow instead.
  final String summaryRoute;

  const ItemCatalogScreen({
    super.key,
    required this.customer,
    this.summaryRoute = '/new-order/summary',
  });

  @override
  State<ItemCatalogScreen> createState() => _ItemCatalogScreenState();
}

class _ItemCatalogScreenState extends State<ItemCatalogScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _isGrid = false;

  @override
  void initState() {
    super.initState();
    // Attach the chosen customer to the order being built.
    context.read<CartBloc>().add(CartCustomerSet(widget.customer));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      context.read<ItemsBloc>().add(const ItemsNextPageRequested());
    }
  }

  Future<void> _configureLine(Item item) async {
    final cart = context.read<CartBloc>();
    final result = await showLineConfigSheet(
      context,
      item: item,
      existing: cart.state.lineFor(item.code),
    );
    if (result is LineSaved) {
      cart.add(CartLineSaved(result.line));
    } else if (result is LineRemoved) {
      cart.add(CartLineRemoved(item.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Catálogo',
      onBack: () => context.pop(),
      actions: [
        IconButton(
          tooltip: _isGrid ? 'Ver como lista' : 'Ver como cuadrícula',
          icon: Icon(_isGrid
              ? Icons.view_list_rounded
              : Icons.grid_view_rounded),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
      ],
      body: Stack(
        children: [
          Column(
            children: [
              _searchHeader(),
              Expanded(child: _list()),
            ],
          ),
          _cartPill(),
        ],
      ),
    );
  }

  Widget _searchHeader() {
    return Container(
      color: AppColors.bgPage,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          ElevatedSearchBar(
            controller: _searchController,
            hintText: 'Buscar ítem por nombre o código',
            onChanged: (q) =>
                context.read<ItemsBloc>().add(ItemsSearchChanged(q)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              BlocBuilder<ItemsBloc, ItemsState>(
                buildWhen: (a, b) => a.inStockOnly != b.inStockOnly,
                builder: (context, state) => _StockFilterChip(
                  active: state.inStockOnly,
                  onToggle: () => context
                      .read<ItemsBloc>()
                      .add(ItemsInStockFilterChanged(!state.inStockOnly)),
                ),
              ),
              const Spacer(),
              BlocBuilder<ItemsBloc, ItemsState>(
                buildWhen: (a, b) =>
                    a.totalCount != b.totalCount || a.status != b.status,
                builder: (context, state) {
                  if (state.status != ItemsStatus.success) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${state.totalCount} ítem(s)',
                    style: const TextStyle(
                        color: AppColors.text2, fontSize: 12),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list() {
    return BlocBuilder<ItemsBloc, ItemsState>(
      builder: (context, state) {
        switch (state.status) {
          case ItemsStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case ItemsStatus.failure:
            return StatusMessage(
              icon: Icons.error_outline_rounded,
              title: state.error ?? 'No se pudieron cargar los ítems',
              actionLabel: 'Reintentar',
              onAction: () =>
                  context.read<ItemsBloc>().add(ItemsSearchChanged(state.query)),
            );
          case ItemsStatus.success:
            if (state.items.isEmpty) {
              final title = state.query.isNotEmpty
                  ? 'Sin resultados para "${state.query}"'
                  : (state.inStockOnly
                      ? 'No hay ítems con stock'
                      : 'No hay ítems');
              return StatusMessage(
                icon: Icons.inventory_2_outlined,
                title: title,
              );
            }
            final cart = context.watch<CartBloc>().state;
            final hasCart = !cart.isEmpty;
            return _isGrid
                ? _grid(state, cart, hasCart)
                : _listView(state, cart, hasCart);
        }
      },
    );
  }

  Widget _listView(ItemsState state, CartState cart, bool hasCart) {
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 8, 16, hasCart ? 96 : 24),
      itemCount: state.items.length + (state.loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= state.items.length) return _loadingMore();
        final item = state.items[i];
        final line = cart.lineFor(item.code);
        return ItemTile(
          item: item,
          inCartQuantity: line?.quantity,
          onTap: () => _configureLine(item),
        );
      },
    );
  }

  Widget _grid(ItemsState state, CartState cart, bool hasCart) {
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 8, 16, hasCart ? 96 : 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: state.items.length + (state.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= state.items.length) return _loadingMore();
        final item = state.items[i];
        final line = cart.lineFor(item.code);
        return ItemGridTile(
          item: item,
          inCartQuantity: line?.quantity,
          onTap: () => _configureLine(item),
        );
      },
    );
  }

  Widget _loadingMore() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _cartPill() {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cart) {
        if (cart.isEmpty) return const SizedBox.shrink();
        return Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: CartPill(
            count: cart.count,
            total: cart.total,
            onTap: () => context.push(widget.summaryRoute),
          ),
        );
      },
    );
  }
}

/// Prominent on/off pill for the "only in-stock" catalog filter. Filled primary
/// when active, outlined and muted when off.
class _StockFilterChip extends StatelessWidget {
  final bool active;
  final VoidCallback onToggle;

  const _StockFilterChip({required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.line,
              width: 1.5,
            ),
            boxShadow: active ? AppShadows.card : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.inventory_2_outlined,
                size: 18,
                color: active ? Colors.white : AppColors.text2,
              ),
              const SizedBox(width: 8),
              Text(
                'Solo con stock',
                style: TextStyle(
                  color: active ? Colors.white : AppColors.text1,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
