/*
Copyright (c) 2019 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.render.shaders.geometry;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.interpolation;
import dlib.image.color;

import dagon.core.bindings;
import dagon.graphics.material;
import dagon.graphics.shader;
import dagon.graphics.state;

class GeometryShader: Shader
{
    string vs = import("Geometry.vert.glsl");
    string fs = import("Geometry.frag.glsl");

    this(Owner owner)
    {
        auto myProgram = New!ShaderProgram(vs, fs, this);
        super(myProgram, owner);

        debug writeln("GeometryShader: program ", program.program);
    }

    override void bind(GraphicsState* state)
    {
        auto idiffuse = "diffuse" in state.material.inputs;
        auto inormal = "normal" in state.material.inputs;
        auto iheight = "height" in state.material.inputs;
        auto ipbr = "pbr" in state.material.inputs;
        auto iroughness = "roughness" in state.material.inputs;
        auto imetallic = "metallic" in state.material.inputs;
        auto itextureScale = "textureScale" in state.material.inputs;
        auto iparallax = "parallax" in state.material.inputs;

        setParameter("modelViewMatrix", state.modelViewMatrix);
        setParameter("projectionMatrix", state.projectionMatrix);
        setParameter("normalMatrix", state.normalMatrix);
        setParameter("viewMatrix", state.viewMatrix);
        setParameter("invViewMatrix", state.invViewMatrix);

        setParameter("layer", cast(float)(state.layer));

        setParameter("textureScale", itextureScale.asVector2f);

        int parallaxMethod = iparallax.asInteger;
        if (parallaxMethod > ParallaxOcclusionMapping)
            parallaxMethod = ParallaxOcclusionMapping;
        if (parallaxMethod < 0)
            parallaxMethod = 0;

        // Diffuse
        if (idiffuse.texture)
        {
            glActiveTexture(GL_TEXTURE0);
            idiffuse.texture.bind();
            setParameter("diffuseTexture", cast(int)0);
            setParameterSubroutine("diffuse", ShaderType.Fragment, "diffuseColorTexture");
        }
        else
        {
            setParameter("diffuseVector", idiffuse.asVector4f);
            setParameterSubroutine("diffuse", ShaderType.Fragment, "diffuseColorValue");
        }

        // Normal/height
        bool haveHeightMap = inormal.texture !is null;
        if (haveHeightMap)
            haveHeightMap = inormal.texture.image.channels == 4;

        if (!haveHeightMap)
        {
            if (inormal.texture is null)
            {
                if (iheight.texture !is null) // we have height map, but no normal map
                {
                    Color4f color = Color4f(0.5f, 0.5f, 1.0f, 0.0f); // default normal pointing upwards
                    inormal.texture = state.material.makeTexture(color, iheight.texture);
                    haveHeightMap = true;
                }
            }
            else
            {
                if (iheight.texture !is null) // we have both normal and height maps
                {
                    inormal.texture = state.material.makeTexture(inormal.texture, iheight.texture);
                    haveHeightMap = true;
                }
            }
        }

        if (inormal.texture)
        {
            setParameter("normalTexture", 1);
            setParameterSubroutine("normal", ShaderType.Fragment, "normalMap");

            glActiveTexture(GL_TEXTURE1);
            inormal.texture.bind();
        }
        else
        {
            setParameter("normalVector", state.material.normal.asVector3f);
            setParameterSubroutine("normal", ShaderType.Fragment, "normalValue");
        }

        // Height and parallax
        // TODO: make these material properties
        float parallaxScale = 0.03f;
        float parallaxBias = -0.01f;
        setParameter("parallaxScale", parallaxScale);
        setParameter("parallaxBias", parallaxBias);

        if (haveHeightMap)
        {
            setParameterSubroutine("height", ShaderType.Fragment, "heightMap");
        }
        else
        {
            float h = 0.0f; //-parallaxBias / parallaxScale;
            setParameter("heightScalar", h);
            setParameterSubroutine("height", ShaderType.Fragment, "heightValue");
            parallaxMethod = ParallaxNone;
        }

        if (parallaxMethod == ParallaxSimple)
            setParameterSubroutine("parallax", ShaderType.Fragment, "parallaxSimple");
        else if (parallaxMethod == ParallaxOcclusionMapping)
            setParameterSubroutine("parallax", ShaderType.Fragment, "parallaxOcclusionMapping");
        else
            setParameterSubroutine("parallax", ShaderType.Fragment, "parallaxNone");

        // PBR
        if (ipbr is null)
        {
            state.material.setInput("pbr", 0.0f);
            ipbr = "pbr" in state.material.inputs;
        }
        if (ipbr.texture is null)
        {
            ipbr.texture = state.material.makeTexture(*iroughness, *imetallic, materialInput(0.0f), materialInput(0.0f));
        }
        glActiveTexture(GL_TEXTURE2);
        ipbr.texture.bind();
        setParameter("pbrTexture", 2);

        if (iroughness.texture is null)
        {
            setParameterSubroutine("roughness", ShaderType.Fragment, "roughnessValue");

            if (iroughness.type == MaterialInputType.Float)
                setParameter("roughnessScalar", iroughness.asFloat);
            else if (iroughness.type == MaterialInputType.Bool)
                setParameter("roughnessScalar", cast(float)iroughness.asBool);
            else if (iroughness.type == MaterialInputType.Integer)
                setParameter("roughnessScalar", cast(float)iroughness.asInteger);
            else if (iroughness.type == MaterialInputType.Vec2)
                setParameter("roughnessScalar", iroughness.asVector2f.r);
            else if (iroughness.type == MaterialInputType.Vec3)
                setParameter("roughnessScalar", iroughness.asVector3f.r);
            else if (iroughness.type == MaterialInputType.Vec4)
                setParameter("roughnessScalar", iroughness.asVector4f.r);
        }
        else
        {
            setParameterSubroutine("roughness", ShaderType.Fragment, "roughnessMap");
        }

        if (imetallic.texture is null)
        {
            setParameterSubroutine("metallic", ShaderType.Fragment, "metallicValue");

            if (imetallic.type == MaterialInputType.Float)
                setParameter("metallicScalar", imetallic.asFloat);
            else if (imetallic.type == MaterialInputType.Bool)
                setParameter("metallicScalar", cast(float)imetallic.asBool);
            else if (imetallic.type == MaterialInputType.Integer)
                setParameter("metallicScalar", cast(float)imetallic.asInteger);
            else if (imetallic.type == MaterialInputType.Vec2)
                setParameter("metallicScalar", imetallic.asVector2f.r);
            else if (imetallic.type == MaterialInputType.Vec3)
                setParameter("metallicScalar", imetallic.asVector3f.r);
            else if (imetallic.type == MaterialInputType.Vec4)
                setParameter("metallicScalar", imetallic.asVector4f.r);
        }
        else
        {
            setParameterSubroutine("metallic", ShaderType.Fragment, "metallicMap");
        }

        glActiveTexture(GL_TEXTURE0);

        super.bind(state);
    }

    override void unbind(GraphicsState* state)
    {
        super.unbind(state);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE0);
    }
}
