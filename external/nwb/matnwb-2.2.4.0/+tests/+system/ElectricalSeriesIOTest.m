classdef ElectricalSeriesIOTest < tests.system.PyNWBIOTest
    
    methods
        function addContainer(testCase, file) %#ok<INUSL>
            devnm = 'dev1';
            egnm = 'tetrode1';
            esnm = 'test_eS';
            devBase = '/general/devices/';
            ephysBase = '/general/extracellular_ephys/';
            devlink = types.untyped.SoftLink([devBase devnm]);
            eglink = types.untyped.ObjectView([ephysBase egnm]);
            etReg = types.untyped.ObjectView([ephysBase 'electrodes']);
            dev = types.core.Device();
            file.general_devices.set(devnm, dev);
            eg = types.core.ElectrodeGroup( ...
                'description', 'tetrode description', ...
                'location', 'tetrode location', ...
                'device', devlink);
            
            electrodes = util.createElectrodeTable();
            electrodes.id.data = 1:4;
            electrodes.vectordata.get('x').data = ones(4, 1);
            electrodes.vectordata.get('y').data = repmat(2, 4, 1);
            electrodes.vectordata.get('z').data = repmat(4, 4, 1);
            electrodes.vectordata.get('imp').data = ones(4, 1);
            electrodes.vectordata.get('location').data = repmat({'CA1'}, 4, 1);
            electrodes.vectordata.get('filtering').data = zeros(4, 1);
            electrodes.vectordata.get('group').data = repmat(eglink, 4, 1);
            electrodes.vectordata.get('group_name').data = repmat({egnm}, 4, 1);
            file.general_extracellular_ephys_electrodes = electrodes;
            
            file.general_extracellular_ephys.set(egnm, eg);
            es = types.core.ElectricalSeries( ...
                'data', [0:9;10:19], ...
                'timestamps', (0:9) .', ...
                'electrodes', ...
                types.hdmf_common.DynamicTableRegion(...
                'data', [0;2],...
                'table', etReg,...
                'description', 'the first and third electrodes'));
            file.acquisition.set(esnm, es);
        end
        
        function c = getContainer(testCase, file) %#ok<INUSL>
            c = file.acquisition.get('test_eS');
        end
    end
end

