classdef ElectrodeGroupIOTest < tests.system.PyNWBIOTest
    methods
        function addContainer(testCase, file) %#ok<INUSL>
            dev = types.core.Device();
            file.general_devices.set('dev1', dev);
            eg = types.core.ElectrodeGroup( ...
                'description', 'a test ElectrodeGroup', ...
                'location', 'a nonexistent place', ...
                'device', types.untyped.SoftLink('/general/devices/dev1'));
            file.general_extracellular_ephys.set('elec1', eg);
        end
        
        function c = getContainer(testCase, file) %#ok<INUSL>
            c = file.general_extracellular_ephys.get('elec1');
        end
    end
end

