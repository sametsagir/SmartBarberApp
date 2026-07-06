import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class BarberReviewsScreen extends StatefulWidget {
  const BarberReviewsScreen({super.key});

  @override
  State<BarberReviewsScreen> createState() => _BarberReviewsScreenState();
}

class _BarberReviewsScreenState extends State<BarberReviewsScreen> {
  List<dynamic> _reviews = [];
  bool _isLoading = false;
  double _avgRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getSalonReviews();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _reviews = result.data!;
          if (_reviews.isNotEmpty) {
            double total = 0.0;
            for (var r in _reviews) {
              total += (r['rating'] as num).toDouble();
            }
            _avgRating = total / _reviews.length;
          } else {
            _avgRating = 5.0;
          }
        } else {
          _reviews = [];
          _avgRating = 5.0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load reviews.')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Reviews'),
        backgroundColor: const Color(0xFF1E1E2F),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2F), Color(0xFF0F0F1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadReviews,
          color: const Color(0xFF9C27B0),
          backgroundColor: const Color(0xFF1E1E2F),
          child: _isLoading && _reviews.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _avgRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (idx) {
                                    final starVal = idx + 1;
                                    return Icon(
                                      starVal <= _avgRating.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 18,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total ${_reviews.length} Reviews',
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.rate_review_outlined,
                              size: 64,
                              color: Colors.white10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Reviews',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _reviews.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                                  const Center(child: Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24)),
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: Text(
                                      'No customers have reviewed this salon yet.',
                                      style: TextStyle(color: Colors.white38, fontSize: 14),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  final review = _reviews[index];
                                  final rating = (review['rating'] as num).toDouble();
                                  final comment = review['comment'] as String? ?? '';
                                  final date = review['createdAt'] as String;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              review['customerName'],
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              date,
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Row(
                                              children: List.generate(5, (idx) {
                                                return Icon(
                                                  idx < rating ? Icons.star : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 14,
                                                );
                                              }),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF9C27B0).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${review['serviceName']} - ${review['stylistName']}',
                                                style: const TextStyle(color: Color(0xFFE040FB), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (comment.trim().isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            '"$comment"',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
