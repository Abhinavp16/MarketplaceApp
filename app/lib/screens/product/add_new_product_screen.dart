import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_fonts.dart';

class AddNewProductScreen extends StatefulWidget {
  const AddNewProductScreen({super.key});

  @override
  State<AddNewProductScreen> createState() => _AddNewProductScreenState();
}

class _AddNewProductScreenState extends State<AddNewProductScreen> {
  String? _selectedCategory;

  // Colors from design
  static const Color primary = Color(0xFF46ec13);
  static const Color backgroundLight = Color(0xFFf6f8f6);
  static const Color backgroundDark = Color(0xFF142210);
  static const Color textDark = Color(0xFF111b0d);
  static const Color borderColor = Color(0xFFd5e7cf);
  static const Color placeholderColor = Color(0xFF5e9a4c);
  static const Color gray200 = Color(0xFFe5e7eb);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // TopAppBar
          Container(
            color: backgroundLight,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: gray200)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.arrow_back_ios, color: textDark),
                    ),
                    Expanded(
                      child: Text(
                        'Add New Product',
                        textAlign: TextAlign.center,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.015 * 18,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.check, color: primary),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Information Section
                  _buildSectionHeader('General Information'),

                  // Product Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Name',
                          style: AppFonts.jakarta(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField('e.g. Combine Harvester X500'),
                      ],
                    ),
                  ),

                  // Category
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: AppFonts.jakarta(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              hint: Text(
                                'Select machinery category',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  color: placeholderColor,
                                ),
                              ),
                              isExpanded: true,
                              icon: Icon(Icons.unfold_more, color: placeholderColor),
                              items: const [
                                DropdownMenuItem(value: 'tractors', child: Text('Tractors')),
                                DropdownMenuItem(value: 'harvesters', child: Text('Harvesters')),
                                DropdownMenuItem(value: 'seeding', child: Text('Seeding & Planting')),
                                DropdownMenuItem(value: 'irrigation', child: Text('Irrigation')),
                              ],
                              onChanged: (value) => setState(() => _selectedCategory = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: AppFonts.jakarta(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 128,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            maxLines: null,
                            expands: true,
                            decoration: InputDecoration(
                              hintText: 'Detailed product description and specifications...',
                              hintStyle: AppFonts.jakarta(
                                fontSize: 16,
                                color: placeholderColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Product Images Section
                  _buildSectionHeader('Product Images'),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Add Image Button
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: borderColor,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: placeholderColor),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add Image',
                                    style: AppFonts.jakarta(
                                      fontSize: 12,
                                      color: placeholderColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Image 1
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB5gk1nD2l7IckZ933Py-pDyifUrPMsI6vMbGDFhQPTXAJC3xlHQUTgw-uH-zzQYYr5N_NL7yGRGOjfLL3Gi2yOZmbldPHC8kMxtc7rVMMzbY2BTh94brKK_puSi3ONH89IebLu3qVYq1O2iAsRMU7cqMI8iBvwQr4Xwnxialw56CY8CYqZYHdc3daJChDYNUpq9zqV3Sfplg4RgoQoW3LHJegDp7qQc5r0uLCnzK5g4gQT_sihlDGwkfFIhB1au5krDOdtlWv2UhgU',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Image 2
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDo_sE-PBchFeDDp_k9t7gxC9HDdtS7gNl52Osi2yu0Flhwf2sTW-vqJhJhqdcUN5eus-Psw_hQMIT8vl1ssFzZks-w2l1BU4GX_qDg3J3q1y3L9DzXWtj3oeBzqw4odoNg3vnLgTxsGLnYlV3ROodCc70oXzLwyvFtFwcuCWPzYvwjeLUqXo2MOlofoZ4oF3LUcfcxo71tKnti4zM12bxLd3xJbm_BhpWi27M92y5i36UlBatFEGARZQ7AJXC1RRMSnNWD_A3Z2Bwi',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pricing Section
                  _buildSectionHeader('Pricing'),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Retail Price (\$)',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField('0.00', isNumber: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Min. Bulk Qty',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField('10', isNumber: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Inventory Section
                  _buildSectionHeader('Inventory'),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Initial Stock',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField('0', isNumber: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Low Stock Alert',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField('2', isNumber: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: backgroundDark,
                              elevation: 8,
                              shadowColor: primary.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Save Product',
                              style: AppFonts.jakarta(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gray200,
                              foregroundColor: Color(0xFF1f2937),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppFonts.jakarta(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: AppFonts.jakarta(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textDark,
          letterSpacing: -0.015 * 18,
        ),
      ),
    );
  }

  Widget _buildTextField(String placeholder, {bool isNumber = false}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: AppFonts.jakarta(
            fontSize: 16,
            color: placeholderColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }
}
