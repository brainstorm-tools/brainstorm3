function st = makecall(args, origin, structargs)

    % check if signed in and grab username, key, domain
    [un, key, domain] = signin;
    if isempty(un) || isempty(key)
        error('Plotly:CredentialsNotFound',...
             ['It looks like you haven''t set up your plotly '...
              'account credentials yet.\nTo get started, save your '...
              'plotly username and API key by calling:\n'...
              '>>> saveplotlycredentials(username, api_key)\n\n'...
              'For more help, see https://plot.ly/MATLAB or contact '...
              'chris@plot.ly.']);
    end

    platform = 'MATLAB';

    args = m2json(args);
    kwargs = m2json(structargs);
    url = [domain '/clientresp'];
    payload = {'platform', platform, 'version', plotly_version, 'args', args, 'un', un, 'key', key, 'origin', origin, 'kwargs', kwargs};

    if (is_octave)
        % use octave super_powers
        resp = urlread(url, 'post', payload);
    else
        % do it matlab way
        resp = urlread(url, 'Post', payload);
    end

    st = loadjson(resp);

    response_handler(resp);

end