function [un, key, domain] = signin(varargin)
% SIGNIN(username, api_key, plotly_domain)  Sign In to a plotly session
%
% See also plotly, signup
%
% For full documentation and examples, see https://plot.ly/matlab/getting-started/

persistent USERNAME KEY PLOTLY_DOMAIN
if nargin > 1 && ischar(varargin{1}) && ischar(varargin{2})
    USERNAME = varargin{1};
    KEY = varargin{2};
    mlock;
elseif isempty(USERNAME) || isempty(KEY)
    creds = loadplotlycredentials();
    USERNAME = creds.username;
    KEY = creds.api_key;
end

un = USERNAME;
key = KEY;

if nargin > 2 && ischar(varargin{3})
    PLOTLY_DOMAIN = varargin{3};
else
    if isempty(PLOTLY_DOMAIN)
        try
            config = loadplotlyconfig();
            PLOTLY_DOMAIN = config.plotly_domain;
        catch 
            % fails cuz either creds haven't been written yet
            % or because plotly_domain wasn't a key in the
            % creds file.
            PLOTLY_DOMAIN = 'https://plot.ly';
        end
    end
end
domain = PLOTLY_DOMAIN;
end
