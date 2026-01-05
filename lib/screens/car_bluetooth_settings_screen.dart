import 'package:flutter/material.dart';
import '../services/car_bluetooth_service.dart';

/// Settings screen for selecting "My Car" Bluetooth device
class CarBluetoothSettingsScreen extends StatefulWidget {
  const CarBluetoothSettingsScreen({super.key});

  @override
  State<CarBluetoothSettingsScreen> createState() => _CarBluetoothSettingsScreenState();
}

class _CarBluetoothSettingsScreenState extends State<CarBluetoothSettingsScreen> {
  final CarBluetoothService _bluetoothService = CarBluetoothService.instance;
  List<Map<String, dynamic>> _pairedDevices = [];
  bool _isLoading = true;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load current selection
      _selectedDeviceId = _bluetoothService.selectedCarDeviceId;
      
      // Get paired devices
      final devices = await _bluetoothService.getPairedDevices();
      
      setState(() {
        _pairedDevices = devices;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading devices: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading Bluetooth devices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDevice(String deviceId, String deviceName) async {
    try {
      await _bluetoothService.setSelectedCarDevice(deviceId);
      
      setState(() {
        _selectedDeviceId = deviceId;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected "$deviceName" as your car'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error selecting device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearSelection() async {
    try {
      await _bluetoothService.setSelectedCarDevice(null);
      
      setState(() {
        _selectedDeviceId = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cleared selection - using automatic detection'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Error clearing selection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select My Car Bluetooth'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Select a Bluetooth device to be treated as your car. '
                          'When you connect/disconnect from this device, the app will automatically save your parking location.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If no device is selected, the app will use automatic detection based on device names.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Current selection
                if (_selectedDeviceId != null)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
                      title: const Text('Currently Selected'),
                      subtitle: Text(
                        _pairedDevices.firstWhere(
                          (d) => d['id'] == _selectedDeviceId,
                          orElse: () => {'name': 'Unknown device'},
                        )['name'] as String,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSelection,
                        tooltip: 'Clear selection',
                      ),
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Devices list
                Expanded(
                  child: _pairedDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No paired devices found',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pair your car Bluetooth in Settings first',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _pairedDevices.length,
                          itemBuilder: (context, index) {
                            final device = _pairedDevices[index];
                            final deviceId = device['id'] as String;
                            final deviceName = device['name'] as String;
                            final isConnected = device['isConnected'] as bool;
                            final isSelected = deviceId == _selectedDeviceId;
                            
                            return ListTile(
                              leading: Icon(
                                isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                              ),
                              title: Text(deviceName),
                              subtitle: Text(
                                isConnected ? 'Connected' : 'Not connected',
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).primaryColor,
                                    )
                                  : null,
                              onTap: () => _selectDevice(deviceId, deviceName),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

