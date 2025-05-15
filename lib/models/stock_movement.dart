// stock_movement.dart
class StockMovement {
  final int? id;
  final int productId;
  final int? variantId;
  final String movementType; // 'in', 'out', 'sale', 'loss', 'adjustment', 'transfer'
  final int quantity;
  final int previousStock;
  final int newStock;
  final DateTime movementDate;
  final String? referenceId; // ID de commande, bon de livraison, etc.
  final String? notes;
  final int? userId;
  final String? sourceLocation; // Pour les transferts entre magasins
  final String? destinationLocation; // Pour les transferts entre magasins
  final String? reasonCode; // Code raison pour les pertes/ajustements

  StockMovement({
    this.id,
    required this.productId,
    this.variantId,
    required this.movementType,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    required this.movementDate,
    this.referenceId,
    this.notes,
    this.userId,
    this.sourceLocation,
    this.destinationLocation,
    this.reasonCode,
  }) {
    // Validation
    if (quantity <= 0) throw ArgumentError("Quantity must be positive");
    if (movementType != 'in' && movementType != 'out' && 
        movementType != 'sale' && movementType != 'loss' && 
        movementType != 'adjustment' && movementType != 'transfer') {
      throw ArgumentError("Invalid movement type");
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'variant_id': variantId,
      'movement_type': movementType,
      'quantity': quantity,
      'previous_stock': previousStock,
      'new_stock': newStock,
      'movement_date': movementDate.toIso8601String(),
      'reference_id': referenceId,
      'notes': notes,
      'user_id': userId,
      'source_location': sourceLocation,
      'destination_location': destinationLocation,
      'reason_code': reasonCode,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'],
      productId: map['product_id'],
      variantId: map['variant_id'],
      movementType: map['movement_type'],
      quantity: map['quantity'],
      previousStock: map['previous_stock'],
      newStock: map['new_stock'],
      movementDate: DateTime.parse(map['movement_date']),
      referenceId: map['reference_id'],
      notes: map['notes'],
      userId: map['user_id'],
      sourceLocation: map['source_location'],
      destinationLocation: map['destination_location'],
      reasonCode: map['reason_code'],
    );
  }

  // Méthode utilitaire pour déterminer si le mouvement est une entrée
  bool get isIncoming => movementType == 'in' || movementType == 'transfer' && 
                        (destinationLocation?.isNotEmpty ?? false);

  // Méthode utilitaire pour déterminer si le mouvement est une sortie
  bool get isOutgoing => movementType == 'out' || movementType == 'sale' || 
                        movementType == 'loss' || 
                        (movementType == 'transfer' && 
                        (sourceLocation?.isNotEmpty ?? false));

  @override
  String toString() {
    return 'StockMovement('
        'id: $id, '
        'productId: $productId, '
        'variantId: $variantId, '
        'type: $movementType, '
        'qty: $quantity, '
        'date: ${movementDate.toIso8601String()}, '
        'ref: $referenceId)';
  }
}