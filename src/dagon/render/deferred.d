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

module dagon.render.deferred;

import std.stdio;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.image.color;

import dagon.core.bindings;
import dagon.core.event;
import dagon.core.time;
import dagon.graphics.entity;
import dagon.graphics.camera;
import dagon.graphics.screensurface;
import dagon.graphics.light;
import dagon.graphics.csm;
import dagon.render.pipeline;
import dagon.render.stage;
import dagon.render.gbuffer;
import dagon.render.shaders.shadow;
import dagon.render.shaders.geometry;
import dagon.render.shaders.environment;
import dagon.render.shaders.sunlight;
import dagon.render.shaders.debugoutput;

class DeferredGeometryStage: RenderStage
{
    GBuffer gbuffer;
    GeometryShader geometryShader;
    
    this(RenderPipeline pipeline, EntityGroup group = null)
    {
        super(pipeline, group);
        geometryShader = New!GeometryShader(this);        
        state.overrideShader = geometryShader;
    }
    
    override void onResize(int w, int h)
    {
        if (gbuffer && view)
        {
            gbuffer.resize(view.width, view.height);
        }
    }
    
    override void render()
    {
        if (!gbuffer && view)
        {
            gbuffer = New!GBuffer(view.width, view.height, this);
        }
        
        if (group)
        {
            gbuffer.bind();
            
            glScissor(0, 0, gbuffer.width, gbuffer.height);
            glViewport(0, 0, gbuffer.width, gbuffer.height);
             
            glClearColor(0.0, 0.0, 0.0, 0.0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            
            foreach(entity; group)
            {
                state.modelViewMatrix = state.viewMatrix * entity.absoluteTransformation;
                state.normalMatrix = state.modelViewMatrix.inverse.transposed;
               
                if (entity.material)
                    entity.material.bind(&state);
                else
                    defaultMaterial.bind(&state);
                
                if (entity.drawable)
                    entity.drawable.render(&state);
                    
                if (entity.material)
                    entity.material.unbind(&state);
                else
                    defaultMaterial.unbind(&state);
            }
            
            gbuffer.unbind();
        }
    }
}

class ShadowStage: RenderStage
{
    EntityGroup lightGroup;
    ShadowShader shadowShader;
    Camera camera;
    
    this(RenderPipeline pipeline)
    {
        super(pipeline);
        shadowShader = New!ShadowShader(this);
        state.overrideShader = shadowShader;
        state.colorMask = false;
        state.culling = false;
    }
    
    override void update(Time t)
    {
        super.update(t);
        
        if (lightGroup)
        {
            foreach(entity; lightGroup)
            {
                Light light = cast(Light)entity;
                if (light && camera)
                {
                    CascadedShadowMap csm = cast(CascadedShadowMap)light.shadowMap;
                    
                    if (csm)
                        csm.camera = camera;
                    light.shadowMap.update(t);
                }
            }
        }
    }
    
    override void render()
    {
        if (group && lightGroup)
        {
            foreach(entity; lightGroup)
            {
                Light light = cast(Light)entity;
                if (light)
                {
                    state.light = light;
                    CascadedShadowMap csm = cast(CascadedShadowMap)light.shadowMap;
                    
                    if (light.type == LightType.Sun && csm)
                        renderCSM(csm);
                }
            }
        }
    }
    
    void renderEntities()
    {
        foreach(entity; group)
        {
            state.modelViewMatrix = state.viewMatrix * entity.absoluteTransformation;
            state.normalMatrix = state.modelViewMatrix.inverse.transposed;
                
            if (entity.material)
                entity.material.bind(&state);
            else
                defaultMaterial.bind(&state);
                
            if (entity.drawable)
                entity.drawable.render(&state);
                
            if (entity.material)
                entity.material.unbind(&state);
            else
                defaultMaterial.unbind(&state);
        }
    }
    
    void renderCSM(CascadedShadowMap csm)
    {
        state.resolution = Vector2f(csm.resolution, csm.resolution);
        state.zNear = csm.area1.zStart;
        state.zFar = csm.area1.zEnd;
    
        state.cameraPosition = csm.area1.position;
        
        glScissor(0, 0, csm.resolution, csm.resolution);
        glViewport(0, 0, csm.resolution, csm.resolution);
        
        glPolygonOffset(3.0, 0.0);
        glDisable(GL_CULL_FACE);
        
        state.viewMatrix = csm.area1.viewMatrix;
        state.invViewMatrix = csm.area1.invViewMatrix;
        state.projectionMatrix = csm.area1.projectionMatrix;
        state.invProjectionMatrix = csm.area1.projectionMatrix.inverse;
        glBindFramebuffer(GL_FRAMEBUFFER, csm.framebuffer1);
        glClear(GL_DEPTH_BUFFER_BIT);
        renderEntities();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        
        state.viewMatrix = csm.area2.viewMatrix;
        state.invViewMatrix = csm.area2.invViewMatrix;
        state.projectionMatrix = csm.area2.projectionMatrix;
        state.invProjectionMatrix = csm.area2.projectionMatrix.inverse;
        glBindFramebuffer(GL_FRAMEBUFFER, csm.framebuffer2);
        glClear(GL_DEPTH_BUFFER_BIT);
        renderEntities();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        
        state.viewMatrix = csm.area3.viewMatrix;
        state.invViewMatrix = csm.area3.invViewMatrix;
        state.projectionMatrix = csm.area3.projectionMatrix;
        state.invProjectionMatrix = csm.area3.projectionMatrix.inverse;
        glBindFramebuffer(GL_FRAMEBUFFER, csm.framebuffer3);
        glClear(GL_DEPTH_BUFFER_BIT);
        renderEntities();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        
        glEnable(GL_CULL_FACE);
        glPolygonOffset(0.0, 0.0);
    }
}

class DeferredEnvironmentStage: RenderStage
{
    DeferredGeometryStage geometryStage;
    ScreenSurface screenSurface;
    EnvironmentShader environmentShader;
    
    this(RenderPipeline pipeline, DeferredGeometryStage geometryStage)
    {
        super(pipeline);
        this.geometryStage = geometryStage;
        screenSurface = New!ScreenSurface(this);
        environmentShader = New!EnvironmentShader(this);
    }
    
    override void render()
    {
        if (view && geometryStage)
        {
            state.colorTexture = geometryStage.gbuffer.colorTexture;
            state.depthTexture = geometryStage.gbuffer.depthTexture;
            state.normalTexture = geometryStage.gbuffer.normalTexture;
            state.pbrTexture = geometryStage.gbuffer.pbrTexture;
            
            Color4f backgroundColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
            if (state.environment)
                backgroundColor = state.environment.backgroundColor;
            
            glScissor(view.x, view.y, view.width, view.height);
            glViewport(view.x, view.y, view.width, view.height);
            
            glClearColor(
                backgroundColor.r, 
                backgroundColor.g,
                backgroundColor.b,
                backgroundColor.a);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            
            environmentShader.bind(&state);
            screenSurface.render(&state);
            environmentShader.unbind(&state);
        }
    }
}

class DeferredLightStage: RenderStage
{
    DeferredGeometryStage geometryStage;
    ScreenSurface screenSurface;
    SunLightShader sunLightShader;
    
    this(RenderPipeline pipeline, DeferredGeometryStage geometryStage)
    {
        super(pipeline);
        this.geometryStage = geometryStage;
        screenSurface = New!ScreenSurface(this);
        sunLightShader = New!SunLightShader(this);
    }
    
    override void render()
    {
        if (group && view && geometryStage)
        {
            state.colorTexture = geometryStage.gbuffer.colorTexture;
            state.depthTexture = geometryStage.gbuffer.depthTexture;
            state.normalTexture = geometryStage.gbuffer.normalTexture;
            state.pbrTexture = geometryStage.gbuffer.pbrTexture;
            
            glScissor(view.x, view.y, view.width, view.height);
            glViewport(view.x, view.y, view.width, view.height);
            
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE);
            
            foreach(entity; group)
            {
                Light light = cast(Light)entity;
                if (light)
                {
                    state.light = light;
                    
                    if (light.type == LightType.Sun)
                    {
                        sunLightShader.bind(&state);
                        screenSurface.render(&state);
                        sunLightShader.unbind(&state);
                    }
                    // TODO: other light types
                }
            }
            
            glDisable(GL_BLEND);
        }
    }
}

enum DebugOutputMode: int
{
    Radiance = 0,
    Albedo = 1,
    Normal = 2,
    Position = 3,
    Roughness = 4,
    Metallic = 5
}

class DeferredDebugOutputStage: RenderStage
{
    DeferredGeometryStage geometryStage;
    ScreenSurface screenSurface;
    DebugOutputShader debugOutputShader;
    DebugOutputMode outputMode = DebugOutputMode.Radiance;
    
    this(RenderPipeline pipeline, DeferredGeometryStage geometryStage)
    {
        super(pipeline);
        this.geometryStage = geometryStage;
        screenSurface = New!ScreenSurface(this);
        debugOutputShader = New!DebugOutputShader(this);
    }
    
    override void render()
    {
        if (view && geometryStage)
        {
            state.colorTexture = geometryStage.gbuffer.colorTexture;
            state.depthTexture = geometryStage.gbuffer.depthTexture;
            state.normalTexture = geometryStage.gbuffer.normalTexture;
            state.pbrTexture = geometryStage.gbuffer.pbrTexture;
            
            Color4f backgroundColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
            if (state.environment)
                backgroundColor = state.environment.backgroundColor;
            
            glScissor(view.x, view.y, view.width, view.height);
            glViewport(view.x, view.y, view.width, view.height);
            
            glClearColor(
                backgroundColor.r, 
                backgroundColor.g,
                backgroundColor.b,
                backgroundColor.a);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            
            debugOutputShader.outputMode = outputMode;
            debugOutputShader.bind(&state);
            screenSurface.render(&state);
            debugOutputShader.unbind(&state);
        }
    }
}
