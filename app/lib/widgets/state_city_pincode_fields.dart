import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Hindi display names for Indian states and union territories. The English
/// name stays the stored / submitted value.
const Map<String, String> indianStateNamesHindi = {
  'Andhra Pradesh': 'आंध्र प्रदेश',
  'Arunachal Pradesh': 'अरुणाचल प्रदेश',
  'Assam': 'असम',
  'Bihar': 'बिहार',
  'Chhattisgarh': 'छत्तीसगढ़',
  'Goa': 'गोवा',
  'Gujarat': 'गुजरात',
  'Haryana': 'हरियाणा',
  'Himachal Pradesh': 'हिमाचल प्रदेश',
  'Jharkhand': 'झारखंड',
  'Karnataka': 'कर्नाटक',
  'Kerala': 'केरल',
  'Madhya Pradesh': 'मध्य प्रदेश',
  'Maharashtra': 'महाराष्ट्र',
  'Manipur': 'मणिपुर',
  'Meghalaya': 'मेघालय',
  'Mizoram': 'मिज़ोरम',
  'Nagaland': 'नागालैंड',
  'Odisha': 'ओडिशा',
  'Punjab': 'पंजाब',
  'Rajasthan': 'राजस्थान',
  'Sikkim': 'सिक्किम',
  'Tamil Nadu': 'तमिलनाडु',
  'Telangana': 'तेलंगाना',
  'Tripura': 'त्रिपुरा',
  'Uttar Pradesh': 'उत्तर प्रदेश',
  'Uttarakhand': 'उत्तराखंड',
  'West Bengal': 'पश्चिम बंगाल',
  'Andaman and Nicobar Islands': 'अंडमान और निकोबार द्वीप समूह',
  'Chandigarh': 'चंडीगढ़',
  'Dadra and Nagar Haveli and Daman and Diu':
      'दादरा और नगर हवेली और दमन और दीव',
  'Delhi': 'दिल्ली',
  'Jammu and Kashmir': 'जम्मू और कश्मीर',
  'Ladakh': 'लद्दाख',
  'Lakshadweep': 'लक्षद्वीप',
  'Puducherry': 'पुडुचेरी',
};

/// State name to show: Hindi when Hindi is selected and known, else as stored.
String localizedStateName(BuildContext context, String state) {
  if (!context.isHindi) return state;
  return indianStateNamesHindi[state.trim()] ?? state;
}

/// A curated India delivery-location list. The PIN filled after choosing a city
/// is a useful default and remains editable because a city can have many PINs.
class StateCityPincodeFields extends StatefulWidget {
  final TextEditingController stateController;
  final TextEditingController cityController;
  final TextEditingController pincodeController;

  const StateCityPincodeFields({
    super.key,
    required this.stateController,
    required this.cityController,
    required this.pincodeController,
  });

  @override
  State<StateCityPincodeFields> createState() => _StateCityPincodeFieldsState();
}

class _StateCityPincodeFieldsState extends State<StateCityPincodeFields> {
  static const _locations = <String, Map<String, String>>{
    'Andhra Pradesh': {
      'Visakhapatnam': '530001',
      'Vijayawada': '520001',
      'Tirupati': '517501',
    },
    'Arunachal Pradesh': {'Itanagar': '791111'},
    'Assam': {'Guwahati': '781001', 'Dibrugarh': '786001', 'Silchar': '788001'},
    'Bihar': {'Patna': '800001', 'Gaya': '823001', 'Muzaffarpur': '842001'},
    'Chhattisgarh': {
      'Bhilai': '490001',
      'Bilaspur': '495001',
      'Durg': '491001',
    },
    'Goa': {'Panaji': '403001', 'Margao': '403601'},
    'Gujarat': {'Ahmedabad': '380001', 'Surat': '395003', 'Vadodara': '390001'},
    'Haryana': {'Gurugram': '122001', 'Faridabad': '121001', 'Hisar': '125001'},
    'Himachal Pradesh': {'Shimla': '171001', 'Dharamshala': '176215'},
    'Jharkhand': {
      'Ranchi': '834001',
      'Jamshedpur': '831001',
      'Dhanbad': '826001',
    },
    'Karnataka': {
      'Bengaluru': '560001',
      'Mysuru': '570001',
      'Hubballi': '580020',
    },
    'Kerala': {
      'Thiruvananthapuram': '695001',
      'Kochi': '682001',
      'Kozhikode': '673001',
    },
    'Madhya Pradesh': {
      'Bhopal': '462001',
      'Indore': '452001',
      'Jabalpur': '482001',
    },
    'Maharashtra': {
      'Mumbai': '400001',
      'Pune': '411001',
      'Nagpur': '440001',
      'Nashik': '422001',
    },
    'Manipur': {'Imphal': '795001'},
    'Meghalaya': {'Shillong': '793001'},
    'Mizoram': {'Aizawl': '796001'},
    'Nagaland': {'Kohima': '797001', 'Dimapur': '797112'},
    'Odisha': {
      'Bhubaneswar': '751001',
      'Cuttack': '753001',
      'Rourkela': '769001',
    },
    'Punjab': {
      'Ludhiana': '141001',
      'Amritsar': '143001',
      'Jalandhar': '144001',
    },
    'Rajasthan': {'Jaipur': '302001', 'Jodhpur': '342001', 'Kota': '324001'},
    'Sikkim': {'Gangtok': '737101'},
    'Tamil Nadu': {
      'Chennai': '600001',
      'Coimbatore': '641001',
      'Madurai': '625001',
    },
    'Telangana': {
      'Hyderabad': '500001',
      'Warangal': '506002',
      'Nizamabad': '503001',
    },
    'Tripura': {'Agartala': '799001'},
    'Uttar Pradesh': {
      'Lucknow': '226001',
      'Kanpur': '208001',
      'Varanasi': '221001',
      'Noida': '201301',
    },
    'Uttarakhand': {'Dehradun': '248001', 'Haridwar': '249401'},
    'West Bengal': {
      'Kolkata': '700001',
      'Siliguri': '734001',
      'Durgapur': '713201',
    },
    'Andaman and Nicobar Islands': {'Port Blair': '744101'},
    'Chandigarh': {'Chandigarh': '160017'},
    'Dadra and Nagar Haveli and Daman and Diu': {
      'Daman': '396210',
      'Silvassa': '396230',
    },
    'Delhi': {'New Delhi': '110001', 'Dwarka': '110075', 'Rohini': '110085'},
    'Jammu and Kashmir': {'Jammu': '180001', 'Srinagar': '190001'},
    'Ladakh': {'Leh': '194101'},
    'Lakshadweep': {'Kavaratti': '682555'},
    'Puducherry': {'Puducherry': '605001'},
  };

  String? _selectedState;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _syncFromControllers();
    widget.stateController.addListener(_syncFromControllers);
    widget.cityController.addListener(_syncFromControllers);
  }

  @override
  void dispose() {
    widget.stateController.removeListener(_syncFromControllers);
    widget.cityController.removeListener(_syncFromControllers);
    super.dispose();
  }

  void _syncFromControllers() {
    final state = widget.stateController.text.trim();
    final city = widget.cityController.text.trim();
    if (_selectedState == state && _selectedCity == city) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentState = widget.stateController.text.trim();
      final currentCity = widget.cityController.text.trim();
      if (_selectedState == currentState && _selectedCity == currentCity) {
        return;
      }
      setState(() {
        _selectedState = currentState.isEmpty ? null : currentState;
        _selectedCity = currentCity.isEmpty ? null : currentCity;
      });
    });
  }

  Map<String, String> get _cities {
    final cities = Map<String, String>.from(_locations[_selectedState] ?? {});
    if (_selectedCity != null && !cities.containsKey(_selectedCity)) {
      cities[_selectedCity!] = widget.pincodeController.text.trim();
    }
    return cities;
  }

  InputDecoration _decoration(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    final states = <String>[..._locations.keys];
    if (_selectedState != null && !states.contains(_selectedState)) {
      states.insert(0, _selectedState!);
    }
    final cities = _cities;
    final l10n = context.l10n;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedState,
          isExpanded: true,
          decoration: _decoration(l10n.fieldState),
          items: states
              .map(
                (state) => DropdownMenuItem(
                  value: state,
                  child: Text(localizedStateName(context, state)),
                ),
              )
              .toList(),
          validator: (value) =>
              value == null || value.isEmpty ? l10n.fieldSelectState : null,
          onChanged: (value) {
            setState(() {
              _selectedState = value;
              _selectedCity = null;
              widget.stateController.text = value ?? '';
              widget.cityController.clear();
              widget.pincodeController.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          isExpanded: true,
          decoration: _decoration(l10n.fieldCity),
          items: cities.entries
              .map(
                (entry) =>
                    DropdownMenuItem(value: entry.key, child: Text(entry.key)),
              )
              .toList(),
          validator: (value) =>
              value == null || value.isEmpty ? l10n.fieldSelectCity : null,
          onChanged: _selectedState == null
              ? null
              : (value) {
                  final defaultPin = cities[value] ?? '';
                  setState(() {
                    _selectedCity = value;
                    widget.cityController.text = value ?? '';
                    widget.pincodeController.text = defaultPin;
                  });
                },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.pincodeController,
          keyboardType: TextInputType.number,
          validator: (value) => value == null || value.trim().isEmpty
              ? l10n.fieldEnterPincode
              : null,
          decoration: _decoration(l10n.fieldPincodeEditable),
        ),
      ],
    );
  }
}
