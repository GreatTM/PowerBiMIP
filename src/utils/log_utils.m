function out = log_utils(action, varargin)
%LOG_UTILS Lightweight logging helpers with character counting and block clearing.
%
%   Description:
%       Provides small utilities to manage console output for PowerBiMIP,
%       including:
%       - Counting printed characters (for later clearing)
%       - Clearing previously printed blocks via backspace/blank overwrite
%       - Printing a unified banner with version and interface label
%
%   Inputs:
%       action  - char: One of:
%                 'printf_count'         -> return number of chars printed
%                 'clear_last_n_chars'   -> erase previous n chars in console
%                 'print_banner'         -> print PowerBiMIP banner
%       varargin - Arguments forwarded to the specific action.
%
%   Output:
%       out - Depends on action:
%             'printf_count'       -> double, number of characters printed
%             'clear_last_n_chars' -> double, number of characters cleared
%             'print_banner'       -> double, number of characters printed
%
%   Example:
%       % Print and count characters
%       cnt = log_utils('printf_count', 'Hello %s\n', 'world');
%       % Clear them later
%       log_utils('clear_last_n_chars', cnt);
%
%   Notes:
%       - Uses only ASCII control sequences (\b) to avoid OS-specific issues.
%       - Avoids global state; callers maintain their own counters.

    switch lower(action)
        case 'printf_count'
            out = local_printf_count(varargin{:});
        case 'clear_last_n_chars'
            out = local_clear_last_n_chars(varargin{:});
        case 'print_banner'
            out = local_print_banner(varargin{:});
        otherwise
            error('log_utils:UnknownAction', 'Unknown action: %s', action);
    end
end

%% Local helpers
function charCount = local_printf_count(fmt, varargin)
%PRINTF_COUNT Wrapper around fprintf that returns printed character count.
    msg = sprintf(fmt, varargin{:});
    fprintf('%s', msg);
    charCount = numel(msg);
end

function cleared = local_clear_last_n_chars(nChars)
%CLEAR_LAST_N_CHARS Clears the last n characters using backspace overwrite.
    if nargin == 0 || isempty(nChars) || nChars <= 0
        cleared = 0;
        return;
    end
    backspaces = repmat(sprintf('\b'), 1, nChars);
    blanks = repmat(' ', 1, nChars);
    fprintf('%s%s%s', backspaces, blanks, backspaces);
    cleared = nChars;
end

function charCount = local_print_banner(verbose, interfaceLabel)
%PRINT_BANNER Prints the unified PowerBiMIP banner (once per interface).
    if nargin < 1
        verbose = 0;
    end
    if verbose < 1
        charCount = 0;
        return;
    end
    if nargin < 2 || isempty(interfaceLabel)
        interfaceLabel = '';
    end
    header = sprintf('Welcome to PowerBiMIP V0.1.0 | © 2025 Yemin Wu, Southeast University\n');
    tagline = sprintf('Open-source, efficient tools for power and energy system bilevel mixed-integer programming.\n');
    repo = sprintf('GitHub: https://github.com/GreatTM/PowerBiMIP\n');
    docs = sprintf('Docs:   https://docs.powerbimip.com\n');
    interfaceLine = '';
    if ~isempty(interfaceLabel)
        interfaceLine = sprintf('%s\n', interfaceLabel);
    end
    separator = sprintf('%s\n', repmat('-', 1, 74));
    allMsg = [header, tagline, repo, docs, interfaceLine, separator];
    fprintf('%s', allMsg);
    charCount = numel(allMsg);
end

