function response = signup(username, email)
% SIGNUP(username, email)  Remote signup to plot.ly and plot.ly API
%     response = signup(username, email) makes an account on plotly and returns a temporary password and an api key
%
% See also plotly, plotlylayout, plotlystyle, signin
%
% For full documentation and examples, see https://plot.ly/api
    platform = 'MATLAB';
    payload = {'version', '0.2', 'un', username, 'email', email,'platform',platform};
    url = 'https://plot.ly/apimkacct';
    resp = urlread(url, 'Post', payload);
    response = loadjson(resp);

    f = fieldnames(response);
    if any(strcmp(f,'error'))
        error(response.error)
    end
    if any(strcmp(f,'warning'))
        fprintf(response.warning)
    end
    if any(strcmp(f,'message'))
        fprintf(response.message)
    end
    if any(strcmp(f,'filename'))
        plotlysession(response.filename)
    end

