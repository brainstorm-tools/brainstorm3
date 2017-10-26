function config = loadplotlyconfig()

userhome = getuserdir();

plotly_config_file = fullfile(userhome,'.plotly','.config');

% check if config exist
if ~exist(plotly_config_file, 'file')
    error('Plotly:ConfigNotFound',...
        ['It looks like you haven''t set up your plotly '...
        'account configuration file yet.\nTo get started, save your '...
        'plotly/stream endpoint domain by calling:\n'...
        '>>> saveplotlyconfig(plotly_domain, plotly_streaming_domain)\n\n'...
        'For more help, see https://plot.ly/MATLAB or contact '...
        'chris@plot.ly.']);
end

fileIDConfig = fopen(plotly_config_file, 'r');

if(fileIDConfig == -1)
    error('plotly:loadconfig', ...
        ['There was an error reading your configuration file at '...
        plotly_credentials_file '. Contact chris@plot.ly for support.']);
end

config_string_array = fread(fileIDConfig, '*char');
config_string = sprintf('%s',config_string_array);
config = loadjson(config_string);

end
