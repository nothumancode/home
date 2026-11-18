{
  "$schema" = "https://pi.dev/schemas/theme.schema.json";
  name = "vercel-dark";
  appearance = "dark";
  vars = import ./palette.nix;
  colors = {
    accent = "white";
    border = "strongBorder";
    borderAccent = "text";
    borderMuted = "border";
    text = "text";
    muted = "muted";
    dim = "quiet";
    success = "green";
    error = "red";
    warning = "amber";
    thinkingText = "muted";

    selectedBg = "selection";
    scrollbarTrack = "border";
    scrollbarThumb = "quiet";
    searchMatchBg = "changeBg";
    searchMatchText = "white";
    userMessageBg = "surface";
    userMessageText = "text";
    customMessageBg = "panel";
    customMessageText = "text";
    customMessageLabel = "muted";

    toolPendingBg = "surface";
    toolSuccessBg = "addBg";
    toolErrorBg = "deleteBg";
    toolTitle = "white";
    toolOutput = "muted";
    toolDiffAdded = "green";
    toolDiffRemoved = "red";
    toolDiffContext = "muted";

    mdHeading = "white";
    mdLink = "blue";
    mdLinkUrl = "muted";
    mdCode = "teal";
    mdCodeBlock = "text";
    mdCodeBlockBorder = "strongBorder";
    mdQuote = "muted";
    mdQuoteBorder = "quiet";
    mdHr = "strongBorder";
    mdListBullet = "muted";

    syntaxComment = "quiet";
    syntaxKeyword = "white";
    syntaxFunction = "text";
    syntaxVariable = "text";
    syntaxString = "teal";
    syntaxNumber = "amber";
    syntaxType = "blue";
    syntaxOperator = "muted";
    syntaxPunctuation = "muted";

    thinkingOff = "strongBorder";
    thinkingMinimal = "quiet";
    thinkingLow = "muted";
    thinkingMedium = "text";
    thinkingHigh = "white";
    thinkingXhigh = "blue";
    thinkingMax = "amber";
    bashMode = "green";
  };
  export = {
    pageBg = "canvas";
    cardBg = "panel";
    infoBg = "surface";
  };
}
