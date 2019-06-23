<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output
    method="xml"
    version="1.0"
    doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
    media-type="application/xml+xhtml"
    omit-xml-declaration="yes"
    indent="yes"
  />

  <xsl:template match="regdoc">
    <html>
      <head>
        <title>Documentation Segment</title>
        <style type="text/css">
          table.register-table {
            border-collapse: collapse;
          }

          table.register-table tr.name-row, table.register-table tr.name-row td, table.register-table tr.name-row th {
            border: solid 1px black;
          }

          table.register-table td, table.register-table th {
            padding: 0.25em;
          }

          table.register-table tr.name-row td.reserved {
            background-color: #888;
          }

          table.register-table tr.position-row td.last {
            text-align: left;
          }

          table.register-table tr.position-row td.first {
            text-align: right;
          }

          table.register-table tr.position-row td.single {
            text-align: center;
          }

          ol.toc {
            counter-reset: item
          }
          li.toc {
            display: block
          }
          li.toc:before {
            content: counters(item, ".") " ";
            counter-increment: item
          }

          dt {
            font-weight: bold;
          }

          .long-table {
            overflow-x: auto;
          }

        </style>
      </head>
      <body>
        <h2>Table of contents</h2>
        <ol class="toc">
          <xsl:apply-templates mode="toc" />
        </ol>

        <xsl:apply-templates />
      </body>
    </html>
  </xsl:template>

  <xsl:template match="peripheral" mode="toc">
    <li class="toc">
      <a href="#{@name}">
        <xsl:value-of select="@name" />
      </a>
      <ol class="toc">
        <xsl:apply-templates mode="toc" />
        <li class="toc">
          <a href="#map_{@name}">Memory map</a>
        </li>
      </ol>
    </li>
  </xsl:template>

  <xsl:template match="register" mode="toc">
    <li class="toc">
      <a href="#{@name}">
        <xsl:value-of select="@name" />
      </a>
    </li>
  </xsl:template>

  <xsl:template match="peripheral">
    <h2>
      <a name="{@name}">
        <xsl:value-of select="@name" />
      </a>
    </h2>

    <xsl:apply-templates />

    <h3><a name="map_{@name}">Memory map</a></h3>
    <table>
      <thead>
        <tr>
          <th>Register name</th>
          <th>Register offset</th>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="register">
          <tr>
            <td>
              <xsl:value-of select="@name" />
            </td>
            <td>
              <xsl:value-of select="@offset" />
              <xsl:value-of select="@address" />
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="register">
    <h3>
      <a name="{@name}">
        <xsl:value-of select="@name" />
      </a>
    </h3>
    <xsl:if test="@address">
      <p>Address: <xsl:value-of select="@address" /></p>
    </xsl:if>
    <xsl:if test="@offset">
      <p>Offset: <xsl:value-of select="@offset" /></p>
    </xsl:if>

    <div class="long-table">
      <table class="register-table">
        <tr class="name-row">
          <xsl:for-each select="field">
            <xsl:variable name="next">
              <xsl:choose>
                <xsl:when test="position() = 1">31</xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="preceding-sibling::*[1]/@first - 1" />
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:if test="@last &lt; $next">
              <td class="reserved" colspan="{$next - @last}"> </td>
            </xsl:if>
            <td colspan="{@last - @first + 1}"><xsl:value-of select="@name" /></td>
          </xsl:for-each>
          <xsl:variable name="first">
            <xsl:choose>
              <xsl:when test="field">
                <xsl:value-of select="field[last()]/@first != 0" />
              </xsl:when>
              <xsl:otherwise>
                32
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <xsl:if test="$first > 0">
            <td class="reserved" colspan="{$first}"> </td>
          </xsl:if>
        </tr>
        <tr class="position-row">
          <xsl:for-each select="field">
            <xsl:variable name="next">
              <xsl:choose>
                <xsl:when test="position() = 1">31</xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="preceding-sibling::*[1]/@first - 1" />
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:if test="@last &lt; $next">
              <xsl:call-template name="register-range">
                <xsl:with-param name="first" select="@last + 1" />
                <xsl:with-param name="last" select="$next" />
              </xsl:call-template>
            </xsl:if>
            <xsl:call-template name="register-range">
              <xsl:with-param name="first" select="@first" />
              <xsl:with-param name="last" select="@last" />
            </xsl:call-template>
          </xsl:for-each>
          <xsl:variable name="first">
            <xsl:choose>
              <xsl:when test="field">
                <xsl:value-of select="field[last()]/@first != 0" />
              </xsl:when>
              <xsl:otherwise>
                32
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <xsl:if test="$first > 0">
            <xsl:call-template name="register-range">
              <xsl:with-param name="first" select="0" />
              <xsl:with-param name="last" select="$first - 1" />
            </xsl:call-template>
          </xsl:if>
        </tr>
      </table>
    </div>

    <xsl:apply-templates />

    <dl>
      <xsl:for-each select="field">
        <dt><xsl:value-of select="@name" /></dt>
        <dd>
          <xsl:apply-templates />
        </dd>
      </xsl:for-each>
    </dl>
  </xsl:template>

  <xsl:template match="field" />

  <xsl:template name="register-range">
    <xsl:param name="first" select="0" />
    <xsl:param name="last" select="31" />
    <xsl:choose>
      <xsl:when test="$first = $last">
        <td class="reserved single"><xsl:value-of select="$last" /></td>
      </xsl:when>
      <xsl:when test="$first = $last - 1">
        <td class="reserved last"><xsl:value-of select="$last" /></td>
        <td class="reserved first"><xsl:value-of select="$first" /></td>
      </xsl:when>
      <xsl:otherwise>
        <td class="reserved last"><xsl:value-of select="$last" /></td>
        <td class="reserved gap" colspan="{$last - $first - 1}"> </td>
        <td class="reserved first"><xsl:value-of select="$first" /></td>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*|/" mode="toc" />

  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="processing-instruction('xml-stylesheet')" />

</xsl:stylesheet>
