class IndianState {
  final String name;
  final String code;

  const IndianState(this.name, this.code);
}

class IndianStates {
  static const List<IndianState> all = [
    IndianState('Andhra Pradesh', '37'),
    IndianState('Arunachal Pradesh', '12'),
    IndianState('Assam', '18'),
    IndianState('Bihar', '10'),
    IndianState('Chhattisgarh', '22'),
    IndianState('Goa', '30'),
    IndianState('Gujarat', '24'),
    IndianState('Haryana', '06'),
    IndianState('Himachal Pradesh', '02'),
    IndianState('Jharkhand', '20'),
    IndianState('Karnataka', '29'),
    IndianState('Kerala', '32'),
    IndianState('Madhya Pradesh', '23'),
    IndianState('Maharashtra', '27'),
    IndianState('Manipur', '14'),
    IndianState('Meghalaya', '17'),
    IndianState('Mizoram', '15'),
    IndianState('Nagaland', '13'),
    IndianState('Odisha', '21'),
    IndianState('Punjab', '03'),
    IndianState('Rajasthan', '08'),
    IndianState('Sikkim', '11'),
    IndianState('Tamil Nadu', '33'),
    IndianState('Telangana', '36'),
    IndianState('Tripura', '16'),
    IndianState('Uttar Pradesh', '09'),
    IndianState('Uttarakhand', '05'),
    IndianState('West Bengal', '19'),
    IndianState('Andaman and Nicobar Islands', '35'),
    IndianState('Chandigarh', '04'),
    IndianState('Dadra and Nagar Haveli and Daman and Diu', '26'),
    IndianState('Delhi', '07'),
    IndianState('Jammu and Kashmir', '01'),
    IndianState('Ladakh', '38'),
    IndianState('Lakshadweep', '31'),
    IndianState('Puducherry', '34'),
    IndianState('Other Territory', '97'),
  ];

  static IndianState getStateByName(String name) {
    return all.firstWhere(
      (s) => s.name.toLowerCase() == name.toLowerCase().trim(),
      orElse: () => const IndianState('Andhra Pradesh', '37'),
    );
  }

  static String getCodeByName(String name) {
    return getStateByName(name).code;
  }
}
