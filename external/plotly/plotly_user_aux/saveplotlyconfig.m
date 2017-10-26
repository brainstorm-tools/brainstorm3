function saveplotlyconfig(plotly_domain,plotly_streaming_domain)
% Save plotly config info.
% Plotly config info are saved as JSON strings
% in ~/.plotly/.config

% catch missing input arguments
if nargin < 1 
    error('plotly:saveconfig', ...
    ['Incorrect number of inputs. Please save your configuration ', ...
    'as follows: >> saveplotlyconfig(plotly_domain,', ...
    '[optional]plotly_streaming_domain)']); 
end

% if the config file exists, then load it up
try
    config = loadplotlyconfig();
catch
    config = struct();
end

% Create the .plotly folder
userhome = getuserdir();

plotly_config_folder   = fullfile(userhome,'.plotly');
plotly_config_file = fullfile(plotly_config_folder, '.config');

[status, mess, messid] = mkdir(plotly_config_folder);

if (status == 0)
    if(~strcmp(messid, 'MATLAB:MKDIR:DirectoryExists'))
        error('plotly:saveconfig',...
            ['Error saving configuration folder at ' ...
            plotly_credentials_folder ': '...
            mess ', ' messid '. Get in touch at ' ...
            'chris@plot.ly for support.']);
    end
end

fileIDConfig = fopen(plotly_config_file, 'w');

if(fileIDConfig == -1)
    error('plotly:saveconfiguration',...
        ['Error opening configuration file at '...
        plotly_credentials_file '. Get in touch at '...
        'chris@plot.ly for support.']);
end

% get user credenitals 
[username, api_key] = signin; 

switch nargin
    case 1
        config.plotly_domain = plotly_domain;
        signin(username, api_key, plotly_domain);
    case 2
        config.plotly_domain = plotly_domain;
        signin(username, api_key, plotly_domain);
        config.plotly_streaming_domain= plotly_streaming_domain;
    otherwise %if neither endpoints are specified, no worries!
end

config_string = m2json(config);

%write the json strings to the cred file
fprintf(fileIDConfig,'%s',config_string);
fclose(fileIDConfig);

end
