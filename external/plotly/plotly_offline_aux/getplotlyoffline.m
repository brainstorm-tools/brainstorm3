function getplotlyoffline(plotly_bundle_url)

    % download bundle 
    [plotly_bundle, extras] = urlread2(plotly_bundle_url, 'get');
   
    % handle response
    if ~extras.isGood
        error(['Whoops! There was an error attempting to ', ...
               'download the MATLAB offline Plotly ', ...
               'bundle. Status: %s %s.'], ...
               num2str(extras.status.value), extras.status.msg); 
    end

    % create Plotly config folder 
    userhome = getuserdir();
    plotly_config_folder = fullfile(userhome, '.plotly');
    [status, mess, messid] = mkdir(plotly_config_folder);
    validatedir(status, mess, messid, 'plotly'); 

    % create plotlyjs folder
    plotly_js_folder = fullfile(plotly_config_folder, 'plotlyjs');
    [status, mess, messid] = mkdir(plotly_js_folder);
    validatedir(status, mess, messid, 'plotlyjs');  

    % save bundle
    bundle = escapechars(plotly_bundle);
    bundle_name = 'plotly-matlab-offline-bundle.js'; 
    bundle_file = fullfile(plotly_js_folder, bundle_name); 
    file_id = fopen(bundle_file, 'w'); 
    fprintf(file_id, '%s', bundle);
    fclose(file_id); 
    
    % success! 
    fprintf(['\nSuccess! You can generate your first offline ', ...
             'graph\nusing the ''offline'' flag of fig2plotly as ', ...
             'follows:\n\n>> plot(1:10); fig2plotly(gcf, ', ... 
             '''offline'', true);\n\n'])
end
