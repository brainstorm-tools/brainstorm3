function TDT2NWB(blockpath, nwb_path)
    [basepath, blockname] = fileparts(blockpath);

    if ~exist('nwb_path', 'var') || isempty(nwb_path)
        nwb_path = fullfile(basepath, [blockname '.nwb']);
    end

    tdt = TDTbin2mat(blockpath);

    %%
    date = datevec([tdt.info.date tdt.info.utcStartTime]);

    file = NwbFile( ...
        'session_description', 'a test NWB File', ...
        'identifier', blockname, ...
        'session_start_time', datestr(date, 'yyyy-mm-dd HH:MM:SS'), ...
        'file_create_date', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    %% Electrode Table

    [file, ecog_channels] = elecs2ElectrodeTable(file, elecspath);
    
    addElectrodeTable(file, tdt)

    x = height(file.general_extracellular_ephys.get('electrodes').data);
    rv = types.untyped.RegionView('/general/extracellular_ephys/electrodes',...
        {[1 x]});

    etr = types.core.ElectrodeTableRegion('data', rv);

    %% ECoG

    stream_names = fieldnames(tdt.streams);

    ecog_stream_names = sort(stream_names(contains(stream_names,'Wav')));

    Data = [];
    for i = 1:length(ecog_stream_names)
        stream = tdt.streams.(ecog_stream_names{i});
        Data = [Data, stream.data'];
    end
    Data = Data(:, ecog_channels);

    es = types.core.ElectricalSeries(...
        'starting_time',stream.startTime,...
        'starting_time_rate',stream.fs,...
        'data',Data',...
        'electrodes', etr,...
        'data_unit','V');

    file.acquisition.set('lfp', es);


    %% ANIN

    stream = tdt.streams.ANIN;

    labels = {'microphone', 'speaker1', 'speaker2', 'anin4'};

    for i = 1:length(labels)
        ts = types.core.TimeSeries('starting_time',stream.startTime,...
            'starting_time_rate',stream.fs,...
            'data',stream.data(i,:)',...
            'data_unit','V?');
        file.acquisition.set(labels{i}, ts);
    end

    %% Cortical Surface



    %% Hilbert AA



    %% write file
    nwbExport(file, nwb_path)

    %% test read
    nwb_read = nwbRead(nwb_path);
end




