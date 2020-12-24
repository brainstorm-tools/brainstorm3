classdef TimeSeriesIOTest < tests.system.PyNWBIOTest
  methods    
    function addContainer(testCase, file) %#ok<INUSL>
      ts = types.core.TimeSeries(...
        'data', (100:10:190) .', ...
        'data_unit', 'SIunit', ...
        'timestamps', (0:9) .', ...
        'data_resolution', 0.1);
      file.acquisition.set('test_timeseries', ts);
    end
    
    function c = getContainer(testCase, file) %#ok<INUSL>
      c = file.acquisition.get('test_timeseries');
    end
  end
end

